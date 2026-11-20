//
//  CloudflareVerifyView.swift
//  MyComic
//
//  A dedicated, user initiated Cloudflare verification container. The web view
//  is only used to let the user complete the interactive check that Cloudflare
//  presents; it never renders normal comic pages. After the check the site
//  cookies are copied into the URLSession cookie store and the failed request
//  is retried by the caller.
//

import SwiftUI
import WebKit

struct CloudflareVerifyView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionViewModel
    @StateObject private var model = VerificationWebModel()
    @State private var isSyncing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                notice

                ZStack(alignment: .top) {
                    VerificationWebView(model: model)
                        .opacity(model.errorMessage == nil ? 1 : 0.25)

                    if model.isLoading {
                        ProgressView(value: max(0.03, model.progress))
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    }
                }

                bottomBar
            }
            .navigationTitle("Cloudflare 验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        session.cancelVerification()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("重新加载") {
                        model.reload()
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Notice

    private var notice: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                Text("请在本页面完成网站提供的交互验证")
                    .font(.footnote)
                    .fontWeight(.semibold)
            }

            Text("验证由 Cloudflare 提供，应用不会自动破解或伪造验证结果。验证完成后点击下方按钮同步 Cookie，应用会用它继续请求数据。cf_clearance 与网络环境及 User-Agent 绑定，同步后仍可能失效。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = model.errorMessage {
                Text("页面加载失败：\(error)")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Bottom actions

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button {
                syncAndClose()
            } label: {
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isSyncing ? "正在同步 Cookie…" : "完成验证并同步 Cookie")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.orange)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSyncing || model.isLoading)

            Text("同步后若仍提示验证失败，说明该 Cookie 无法用于原生请求。应用会如实提示，不会假装成功。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(Color(.systemBackground))
    }

    private func syncAndClose() {
        guard let webView = model.webView else { return }
        isSyncing = true

        if let agent = webView.customUserAgent, !agent.isEmpty {
            UserAgentProvider.store(webViewAgent: agent)
        }

        CookieManager.syncFromWebView(store: webView.configuration.websiteDataStore) { count in
            isSyncing = false
            session.completeVerification(cookieCount: count)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Web view model

final class VerificationWebModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var isLoading = true
    @Published var progress: Double = 0
    @Published var errorMessage: String?

    private(set) weak var webView: WKWebView?
    private var progressObservation: NSKeyValueObservation?

    func attach(to webView: WKWebView) {
        guard self.webView == nil else { return }
        self.webView = webView
        webView.navigationDelegate = self
        // Keep the web view and URLSession on the same User-Agent so that a
        // cf_clearance cookie obtained here is more likely to be accepted.
        webView.customUserAgent = UserAgentProvider.current
        webView.allowsBackForwardNavigationGestures = true

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
            let value = view.estimatedProgress
            DispatchQueue.main.async {
                self?.progress = value
            }
        }

        webView.load(URLRequest(url: CookieManager.verificationURL))
    }

    func reload() {
        errorMessage = nil
        isLoading = true
        webView?.reload()
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        errorMessage = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        progress = 1
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    private func handle(_ error: Error) {
        let nsError = error as NSError
        // Navigating away / being replaced by a redirect is not a real failure.
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
        isLoading = false
        errorMessage = error.localizedDescription
    }
}

// MARK: - Representable

struct VerificationWebView: UIViewRepresentable {
    let model: VerificationWebModel

    func makeUIView(context: Context) -> WKWebView {
        let configuration = CookieManager.makeWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        model.attach(to: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
