//
//  SessionViewModel.swift
//  MyComic
//
//  Global session state: Cloudflare verification, cookies and access checks.
//

import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var isPresentingVerification = false
    @Published private(set) var cookieStatus = CookieManager.status()
    @Published private(set) var isVerifying = false
    @Published private(set) var lastVerificationMessage: String?

    private var retryAction: (() -> Void)?

    func presentVerification(retry: (() -> Void)? = nil) {
        retryAction = retry
        isPresentingVerification = true
    }

    func refreshStatus() {
        cookieStatus = CookieManager.status()
    }

    /// Called by the verification sheet after cookies were copied.
    func completeVerification(cookieCount: Int) {
        refreshStatus()
        lastVerificationMessage = cookieCount > 0
            ? "已同步 \(cookieCount) 个 Cookie，正在重试请求…"
            : "未获取到站点 Cookie，请确认验证页面已完全加载。"

        let action = retryAction
        retryAction = nil
        isPresentingVerification = false

        if cookieCount > 0 {
            action?()
        }
    }

    func cancelVerification() {
        retryAction = nil
        isPresentingVerification = false
    }

    /// Re-checks whether the current session can reach the site.
    func verifyAccess() async -> Result<Void, AppError> {
        isVerifying = true
        defer { isVerifying = false }
        do {
            try await MyComicAPI.shared.verifyAccess()
            refreshStatus()
            lastVerificationMessage = "访问正常"
            return .success(())
        } catch let error as AppError {
            lastVerificationMessage = error.localizedDescription
            return .failure(error)
        } catch {
            let wrapped = AppError.other(error.localizedDescription)
            lastVerificationMessage = wrapped.localizedDescription
            return .failure(wrapped)
        }
    }
}
