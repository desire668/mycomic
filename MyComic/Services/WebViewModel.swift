//
//  WebViewModel.swift
//  MyComic
//
//  Wraps a single WKWebView: navigation state, progress, error handling,
//  pull-to-refresh and external-link routing. One instance per tab so the
//  web view — and the page it is showing — lives as long as the app does.
//

import Foundation
import UIKit
import WebKit

enum WebLoadError: Equatable {
    case offline
    case timeout
    case hostUnavailable
    case server(code: Int)
    case insecure
    case other(String)

    var title: String {
        switch self {
        case .offline: return "网络未连接"
        case .timeout: return "连接超时"
        case .hostUnavailable: return "无法访问服务器"
        case let .server(code): return "服务器错误 (\(code))"
        case .insecure: return "不安全的连接"
        case .other: return "页面加载失败"
        }
    }

    var message: String {
        switch self {
        case .offline:
            return "请检查 Wi-Fi 或蜂窝网络后重试。"
        case .timeout:
            return "网络响应时间过长，请稍后重试。"
        case .hostUnavailable:
            return "暂时无法连接到 mycomic.com，请稍后重试。"
        case .server:
            return "服务器暂时无法处理请求，请稍后重试。"
        case .insecure:
            return "该地址不是安全的 HTTPS 连接，已停止加载。"
        case let .other(reason):
            return reason
        }
    }
}

final class WebViewModel: NSObject, ObservableObject {
    // MARK: - Published state

    @Published private(set) var progress: Double = 0
    @Published private(set) var isLoading = false
    @Published private(set) var pageTitle: String = ""
    @Published private(set) var currentURL: URL?
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var error: WebLoadError?
    @Published private(set) var hasFinishedFirstLoad = false
    @Published private(set) var isReaderPage = false

    /// Human readable title, falls back to the page title or the tab name.
    var displayTitle: String {
        if !pageTitle.isEmpty { return pageTitle }
        return fallbackTitle
    }

    let tab: WebTab?
    let webView: WKWebView
    private let fallbackTitle: String

    private var observations: [NSKeyValueObservation] = []
    private let refreshControl = UIRefreshControl()
    private var didStartLoading = false
    private var isDisposed = false
    private let pendingURL: URL?

    // MARK: - Init

    /// The first load is deferred until `startIfNeeded()` so that tabs which
    /// are never opened do not consume network or memory.
    init(tab: WebTab? = nil, fallbackTitle: String? = nil, startURL: URL? = nil) {
        self.tab = tab
        self.fallbackTitle = fallbackTitle ?? tab?.navigationTitle ?? "MyComic"
        self.pendingURL = startURL
        self.webView = BrowserSession.makeWebView()
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        refreshControl.tintColor = .secondaryLabel
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        observeWebView()
    }

    /// Loads the tab's first page exactly once.
    func startIfNeeded() {
        guard !didStartLoading, !isDisposed else { return }
        didStartLoading = true
        guard let url = pendingURL ?? tab?.initialURL else { return }
        load(url)
    }

    // MARK: - Observation

    private func observeWebView() {
        observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self = self else { return }
            let value = webView.estimatedProgress
            self.progress = value
            if value >= 1.0, !webView.isLoading {
                self.isLoading = false
            }
        })

        observations.append(webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
            guard let self = self else { return }
            self.isLoading = webView.isLoading
            if !webView.isLoading {
                self.refreshControl.endRefreshing()
                if self.progress >= 0.99 { self.progress = 0 }
            }
        })

        observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
            self?.canGoBack = webView.canGoBack
        })

        observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
            self?.canGoForward = webView.canGoForward
        })

        observations.append(webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            guard let title = webView.title, !title.isEmpty else { return }
            self?.pageTitle = title
        })

        observations.append(webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
            guard let url = webView.url else { return }
            self?.currentURL = url
            self?.isReaderPage = url.path.contains("/chapters/")
        })
    }

    // MARK: - Commands

    func load(_ url: URL) {
        guard !isDisposed else { return }
        guard url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http" else {
            error = .insecure
            return
        }
        error = nil
        didStartLoading = true
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        webView.load(request)
    }

    func reload() {
        error = nil
        if webView.url == nil {
            if let url = pendingURL ?? tab?.initialURL { load(url) }
        } else {
            webView.reload()
        }
    }

    /// Retry after a failure: re-issues the failed request rather than reloading
    /// the (empty) current page.
    func retry() {
        error = nil
        if webView.url == nil, let url = pendingURL ?? tab?.initialURL {
            load(url)
        } else {
            webView.reloadFromOrigin()
        }
    }

    func goBack() {
        guard webView.canGoBack else { return }
        error = nil
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else { return }
        error = nil
        webView.goForward()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    /// Reloads the current page while keeping the navigation history intact.
    /// Tabs that were never opened stay unloaded.
    func reloadAfterDataChange() {
        if webView.url != nil {
            webView.reload()
        }
    }

    func updateSearchURL(_ url: URL) {
        pageTitle = ""
        load(url)
    }

    func dispose() {
        guard !isDisposed else { return }
        isDisposed = true
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.scrollView.refreshControl = nil
    }

    @objc private func handleRefresh() {
        error = nil
        if webView.url == nil, let url = pendingURL ?? tab?.initialURL {
            load(url)
        } else {
            webView.reload()
        }
    }

    // MARK: - Helpers

    private func handleNavigationFailure(_ error: Error) {
        guard !isDisposed else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }
        refreshControl.endRefreshing()
        isLoading = false
        progress = 0

        if nsError.domain == "WebKitErrorDomain", nsError.code == 102 {
            // Frame load interrupted by a policy change (external link).
            return
        }

        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed:
            self.error = .offline
        case NSURLErrorTimedOut:
            self.error = .timeout
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
            self.error = .hostUnavailable
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
            self.error = .insecure
        default:
            self.error = .other(nsError.localizedDescription)
        }
    }

    private func openExternally(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // Sub-frames (ads, players) are always allowed; only the main frame
        // is subject to external-link routing.
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? (navigationAction.targetFrame == nil)

        if scheme == "http" || scheme == "https" {
            if Site.isInternal(url) || !isMainFrame {
                decisionHandler(.allow)
            } else {
                openExternally(url)
                decisionHandler(.cancel)
            }
            return
        }

        if scheme == "mailto" || scheme == "tel" {
            openExternally(url)
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        error = nil
        isLoading = true
        progress = max(progress, 0.05)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        error = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        refreshControl.endRefreshing()
        hasFinishedFirstLoad = true
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if let url = webView.url {
            currentURL = url
            isReaderPage = url.path.contains("/chapters/")
        }
        if let title = webView.title, !title.isEmpty {
            pageTitle = title
        }
        // Delay hiding the bar so the fill animation is visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self, !self.isLoading else { return }
            self.progress = 0
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        handleNavigationFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !isDisposed else { return }
        error = .other("网页进程已被系统回收，正在重新加载。")
        webView.reload()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse,
           navigationResponse.isForMainFrame,
           response.statusCode >= 500 {
            error = .server(code: response.statusCode)
        }
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate

extension WebViewModel: WKUIDelegate {
    /// Keeps target="_blank" links inside the app instead of silently dropping them.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if Site.isInternal(url) {
                webView.load(navigationAction.request)
            } else {
                openExternally(url)
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        presentAlert(title: webView.title ?? "提示", message: message) {
            completionHandler()
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        presentConfirm(title: webView.title ?? "请确认", message: message) { confirmed in
            completionHandler(confirmed)
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        presentPrompt(title: webView.title ?? "请输入", message: prompt, defaultText: defaultText) { text in
            completionHandler(text)
        }
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        var controller = windowScene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    private func presentAlert(title: String, message: String, completion: @escaping () -> Void) {
        guard let controller = topViewController() else {
            completion()
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completion() })
        controller.present(alert, animated: true)
    }

    private func presentConfirm(title: String, message: String, completion: @escaping (Bool) -> Void) {
        guard let controller = topViewController() else {
            completion(false)
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completion(false) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completion(true) })
        controller.present(alert, animated: true)
    }

    private func presentPrompt(title: String,
                               message: String,
                               defaultText: String?,
                               completion: @escaping (String?) -> Void) {
        guard let controller = topViewController() else {
            completion(defaultText)
            return
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = defaultText
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completion(nil) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion(alert.textFields?.first?.text)
        })
        controller.present(alert, animated: true)
    }
}
