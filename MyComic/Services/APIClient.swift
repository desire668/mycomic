//
//  APIClient.swift
//  MyComic
//
//  URLSession wrapper for mycomic.com. Adds the headers the site expects, the
//  persisted session cookies and reliable Cloudflare / HTTP error mapping.
//

import Foundation
import CoreFoundation

enum MyComicSite {
    static let baseURL = "https://mycomic.com"
    static let chineseBaseURL = "https://mycomic.com/cn"
    static let cdnBaseURL = "https://biccam.com"
    static let referer = "https://mycomic.com/"
    static let homeURL = "https://mycomic.com/cn"
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 25
            configuration.timeoutIntervalForResource = 60
            configuration.httpCookieStorage = HTTPCookieStorage.shared
            configuration.httpShouldSetCookies = true
            configuration.requestCachePolicy = .useProtocolCachePolicy
            configuration.urlCache = URLCache.shared
            self.session = URLSession(configuration: configuration)
        }
    }

    // MARK: - HTML

    func fetchHTML(url: URL, referer: String = MyComicSite.referer) async throws -> String {
        let request = makeRequest(url: url, referer: referer, accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8")
        let (data, response) = try await perform(request)

        guard (200..<300).contains(response.statusCode) else {
            throw mapHTTPError(status: response.statusCode, data: data, response: response)
        }

        if let text = String(data: data, encoding: .utf8) {
            if CloudflareDetector.isChallenge(status: response.statusCode, headers: response.allHeaderFields, body: text) {
                throw AppError.cloudflareRequired(response.statusCode)
            }
            return text
        }

        // Some pages may declare a non UTF-8 charset; retry with GB18030 as a fallback.
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let text = String(data: data, encoding: gb18030) {
            return text
        }

        throw AppError.parse("页面编码无法识别")
    }

    // MARK: - Images

    func fetchImageData(url: URL) async throws -> Data {
        var request = makeRequest(
            url: url,
            referer: MyComicSite.referer,
            accept: "image/avif,image/webp,image/apng,image/*,*/*;q=0.8"
        )
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, response) = try await perform(request)

        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 403 {
                throw AppError.other("图片请求被拒绝 (403)，可能缺少 Referer 或链接已失效")
            }
            throw AppError.http(response.statusCode)
        }
        guard !data.isEmpty else {
            throw AppError.parse("图片内容为空")
        }
        return data
    }

    // MARK: - POST (used by the experimental login form)

    func postJSON(url: URL, body: [String: String], csrfToken: String?, referer: String) async throws -> (status: Int, body: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(UserAgentProvider.current, forHTTPHeaderField: "User-Agent")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        if let csrfToken = csrfToken {
            request.setValue(csrfToken, forHTTPHeaderField: "X-XSRF-TOKEN")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await perform(request)
        let text = String(data: data, encoding: .utf8) ?? ""
        if CloudflareDetector.isChallenge(status: response.statusCode, headers: response.allHeaderFields, body: text) {
            throw AppError.cloudflareRequired(response.statusCode)
        }
        return (response.statusCode, text)
    }

    // MARK: - Request building

    func makeRequest(url: URL, referer: String?, accept: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(UserAgentProvider.current, forHTTPHeaderField: "User-Agent")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if let referer = referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        return request
    }

    // MARK: - Perform

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AppError.other("服务器返回了无法识别的响应")
            }
            return (data, http)
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                throw AppError.offline
            case .timedOut:
                throw AppError.timedOut
            case .cancelled:
                throw AppError.cancelled
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                throw AppError.other("无法连接到 mycomic.com，请检查网络或稍后重试。")
            case .secureConnectionFailed, .serverCertificateUntrusted:
                throw AppError.other("HTTPS 安全连接失败。")
            default:
                throw AppError.other(error.localizedDescription)
            }
        } catch {
            throw AppError.other(error.localizedDescription)
        }
    }

    private func mapHTTPError(status: Int, data: Data, response: HTTPURLResponse) -> AppError {
        let body = String(data: data, encoding: .utf8) ?? ""
        if CloudflareDetector.isChallenge(status: status, headers: response.allHeaderFields, body: body) {
            return .cloudflareRequired(status)
        }
        return .http(status)
    }
}

// MARK: - Cloudflare detection

enum CloudflareDetector {
    private static let markers = [
        "just a moment",
        "challenge-platform",
        "cf-browser-verification",
        "attention required",
        "cf-error-details",
        "__cf_chl",
        "checking your browser",
        "verify you are human"
    ]

    static func isChallenge(status: Int, headers: [AnyHashable: Any], body: String) -> Bool {
        if let mitigated = headerValue("cf-mitigated", in: headers), mitigated.lowercased() == "challenge" {
            return true
        }
        guard status == 403 || status == 503 || status == 429 else { return false }
        let lowered = body.lowercased()
        return markers.contains { lowered.contains($0) }
    }

    private static func headerValue(_ name: String, in headers: [AnyHashable: Any]) -> String? {
        for (key, value) in headers {
            if let key = key as? String, key.caseInsensitiveCompare(name) == .orderedSame {
                return value as? String
            }
        }
        return nil
    }
}

// MARK: - User agent

enum UserAgentProvider {
    private static let defaultsKey = "mycomic.userAgent"

    /// The site is protected by Cloudflare, whose clearance cookie is bound to
    /// the User-Agent. When the user completes verification in the web view we
    /// persist that web view's UA and reuse it for every URLSession request.
    static var current: String {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey), !stored.isEmpty {
            return stored
        }
        return defaultAgent
    }

    static func store(webViewAgent: String) {
        let trimmed = webViewAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != defaultAgent else { return }
        UserDefaults.standard.set(trimmed, forKey: defaultsKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    static let defaultAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
}
