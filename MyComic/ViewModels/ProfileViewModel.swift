//
//  ProfileViewModel.swift
//  MyComic
//
//  Account state and the (experimental) native login form. The site exposes a
//  Laravel form at POST /cn/login, verified in docs/API_ANALYSIS.md; the success
//  response shape could not be verified without an account, so every result is
//  reported to the user verbatim instead of being assumed.
//

import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    enum LoginState: Equatable {
        case unknown
        case signedOut
        case signedIn
    }

    @Published private(set) var loginState: LoginState = .unknown
    @Published private(set) var isChecking = false
    @Published private(set) var isLoggingIn = false
    @Published var message: String?

    @Published var email = ""
    @Published var password = ""

    private let client = APIClient.shared
    private var cookiesURL: URL? { URL(string: "https://mycomic.com/cn/bookmarks") }

    // MARK: - Login state

    func checkLoginState() async {
        guard let url = cookiesURL else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            // Visiting the bookmarks page also refreshes the XSRF-TOKEN cookie.
            let html = try await client.fetchHTML(url: url, referer: "https://mycomic.com/cn")
            if html.contains("登入以继续") || html.contains("登入 註册帐户") || html.contains("登入 註冊帳戶") {
                loginState = .signedOut
            } else {
                loginState = .signedIn
            }
        } catch let error as AppError {
            loginState = .unknown
            message = error.localizedDescription
        } catch {
            loginState = .unknown
            message = error.localizedDescription
        }
    }

    // MARK: - Login

    func login() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            message = "请输入邮箱与密码。"
            return
        }
        guard let bookmarksURL = cookiesURL,
              let loginURL = URL(string: "https://mycomic.com/cn/login") else { return }

        isLoggingIn = true
        message = nil
        defer { isLoggingIn = false }

        do {
            // 1. Obtain the XSRF-TOKEN cookie from the site.
            _ = try await client.fetchHTML(url: bookmarksURL, referer: "https://mycomic.com/cn")

            let token = HTTPCookieStorage.shared.cookies?
                .first { $0.name == "XSRF-TOKEN" && $0.domain.contains("mycomic.com") }?
                .value
                .removingPercentEncoding

            // 2. Submit the form.
            let result = try await client.postJSON(
                url: loginURL,
                body: ["email": trimmedEmail, "password": password],
                csrfToken: token,
                referer: bookmarksURL.absoluteString
            )

            // 3. Verify by loading the bookmarks page again.
            let html = try await client.fetchHTML(url: bookmarksURL, referer: "https://mycomic.com/cn")
            if !html.contains("登入以继续") && (200..<300).contains(result.status) {
                loginState = .signedIn
                message = "登录成功。收藏仍以本地书架为准，服务器同步未实现。"
                password = ""
            } else if result.status == 422 {
                loginState = .signedOut
                message = "账号或密码不正确（站点返回 422）。"
            } else if result.status == 419 {
                loginState = .signedOut
                message = "CSRF 校验失败（419），请重新尝试。"
            } else {
                loginState = .signedOut
                message = "登录未成功（HTTP \(result.status)）。"
            }
        } catch let error as AppError {
            message = error.localizedDescription
        } catch {
            message = error.localizedDescription
        }
    }

    func clearSession() {
        CookieManager.clear { [weak self] in
            guard let self = self else { return }
            self.loginState = .signedOut
            self.message = "已清除站点 Cookie，Cloudflare 验证状态也会重置。"
        }
    }
}
