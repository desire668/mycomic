//
//  CookieManager.swift
//  MyComic
//
//  Bridges cookies between the Cloudflare verification WKWebView and the
//  URLSession cookie store, and exposes the session status to the UI.
//

import Foundation
import WebKit

enum CookieManager {
    static let domain = "mycomic.com"

    // MARK: - Status

    struct Status {
        var cookieCount: Int
        var hasClearance: Bool
        var clearanceExpiry: Date?
        var sessionCookieCount: Int
        var userAgent: String

        var clearanceDescription: String {
            guard hasClearance else { return "未取得" }
            if let expiry = clearanceExpiry {
                return "有效（至 \(Self.dateFormatter.string(from: expiry))）"
            }
            return "已取得"
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter
        }()
    }

    static func status() -> Status {
        let cookies = HTTPCookieStorage.shared.cookies?.filter { $0.domain.contains(domain) } ?? []
        let clearance = cookies.first { $0.name == "cf_clearance" }
        let sessionCookies = cookies.filter { $0.name != "cf_clearance" }
        let now = Date()
        let hasClearance = clearance.map { cookie in
            guard let expiry = cookie.expiresDate else { return true }
            return expiry > now
        } ?? false
        return Status(
            cookieCount: cookies.count,
            hasClearance: hasClearance,
            clearanceExpiry: clearance?.expiresDate,
            sessionCookieCount: sessionCookies.count,
            userAgent: UserAgentProvider.current
        )
    }

    // MARK: - Sync from WKWebView

    /// Copies every cookie of the site from the web view data store into the
    /// shared URLSession cookie store. Only cookies for `mycomic.com` and
    /// `biccam.com` are copied.
    static func syncFromWebView(store: WKWebsiteDataStore, completion: @escaping (Int) -> Void) {
        store.httpCookieStore.getAllCookies { cookies in
            let relevant = cookies.filter { cookie in
                cookie.domain.contains("mycomic.com") || cookie.domain.contains("biccam.com")
            }
            for cookie in relevant {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
            DispatchQueue.main.async { completion(relevant.count) }
        }
    }

    /// Removes website cookies for the site from both stores.
    static func clear(store: WKWebsiteDataStore = .default(), completion: @escaping () -> Void) {
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies where cookie.domain.contains(domain) || cookie.domain.contains("biccam.com") {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }

        let group = DispatchGroup()
        group.enter()
        store.httpCookieStore.getAllCookies { cookies in
            let targets = cookies.filter { $0.domain.contains(domain) || $0.domain.contains("biccam.com") }
            guard !targets.isEmpty else {
                group.leave()
                return
            }
            let inner = DispatchGroup()
            for cookie in targets {
                inner.enter()
                store.httpCookieStore.delete(cookie) { inner.leave() }
            }
            inner.notify(queue: .global()) { group.leave() }
        }
        group.notify(queue: .main) { completion() }
    }

    // MARK: - Verification page

    /// The URL used for the user initiated Cloudflare verification.
    static var verificationURL: URL {
        URL(string: MyComicSite.chineseBaseURL) ?? URL(string: "https://mycomic.com")!
    }

    static func makeWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        configuration.applicationNameForUserAgent = "MyComic/1.0"
        return configuration
    }
}
