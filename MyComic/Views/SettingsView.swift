//
//  SettingsView.swift
//  MyComic
//
//  Native settings: cache, cookies, live network status, version and about.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var network: NetworkMonitor
    var onDataCleared: () -> Void

    @State private var isClearingCache = false
    @State private var showCookieConfirmation = false
    @State private var toastMessage: String?

    var body: some View {
        List {
            dataSection
            networkSection
            aboutSection
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showCookieConfirmation) {
            Alert(
                title: Text("清除 Cookie 和登录状态？"),
                message: Text("此操作会删除 mycomic.com 保存的 Cookie 与本地会话数据，你需要在网页中重新登录。"),
                primaryButton: .destructive(Text("清除")) {
                    clearCookies()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                ToastView(text: message)
                    .padding(.bottom, 26)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Sections

    private var dataSection: some View {
        Section(
            header: Text("网页数据"),
            footer: Text("清除 Cookie 会退出网站账号并删除本地登录会话。此操作不可撤销。")
        ) {
            Button {
                clearCache()
            } label: {
                HStack {
                    Label("清除网页缓存", systemImage: "trash")
                        .foregroundColor(.primary)
                    Spacer()
                    if isClearingCache {
                        ProgressView()
                    }
                }
            }
            .disabled(isClearingCache)

            Button {
                showCookieConfirmation = true
            } label: {
                Label("清除 Cookie 与登录状态", systemImage: "person.crop.circle.badge.xmark")
                    .foregroundColor(.red)
            }
        }
    }

    private var networkSection: some View {
        Section(header: Text("网络")) {
            HStack {
                Label(network.statusDescription, systemImage: network.isConnected ? "wifi" : "wifi.slash")
                    .foregroundColor(.primary)
                Spacer()
                Circle()
                    .fill(network.isConnected ? Color.green : Color.red)
                    .frame(width: 9, height: 9)
            }

            HStack {
                Text("连接类型")
                Spacer()
                Text(network.connectionTypeDescription)
                    .foregroundColor(.secondary)
            }

            Button {
                openSiteInSafari()
            } label: {
                Label("在 Safari 中打开网站", systemImage: "safari")
                    .foregroundColor(.primary)
            }
        }
    }

    private var aboutSection: some View {
        Section(header: Text("关于")) {
            HStack {
                Text("应用版本")
                Spacer()
                Text(AppInfo.displayVersion)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("网站")
                Spacer()
                Text(Site.host)
                    .foregroundColor(.secondary)
            }
            NavigationLink(destination: AboutView()) {
                Text("关于 MyComic")
            }
        }
    }

    // MARK: - Actions

    private func clearCache() {
        isClearingCache = true
        BrowserSession.clearCache { [self] in
            isClearingCache = false
            onDataCleared()
            showToast("网页缓存已清除")
        }
    }

    private func clearCookies() {
        BrowserSession.clearCookies { [self] in
            onDataCleared()
            showToast("Cookie 与登录状态已清除")
        }
    }

    private func openSiteInSafari() {
        UIApplication.shared.open(Site.home, options: [:], completionHandler: nil)
    }

    private func showToast(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.78))
            .clipShape(Capsule())
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.95, green: 0.36, blue: 0.20),
                                            Color(red: 0.85, green: 0.18, blue: 0.35)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                            Text("M")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MyComic")
                                .font(.title3.weight(.bold))
                            Text("版本 \(AppInfo.displayVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                section(
                    title: "应用说明",
                    body: "MyComic 是一个基于 SwiftUI 与 WKWebView 的 iOS 客户端，用于在 iPhone 和 iPad 上浏览 mycomic.com 网站。应用本身不存储、不转载、不分发任何漫画内容，所有页面与图片均直接来自官方网站。"
                )

                section(
                    title: "账号与访问控制",
                    body: "应用完全保留网站自身的登录、Cookie 和会话机制，不绕过任何登录验证、付费机制、访问控制或 DRM。若网站要求登录或付费，你需要在网页中按照网站流程自行完成。"
                )

                section(
                    title: "隐私",
                    body: "应用不收集个人数据，不包含第三方统计或广告 SDK。浏览数据（Cookie、缓存）仅保存在本机，可在「设置」中随时清除。"
                )

                section(
                    title: "免责声明",
                    body: "本应用为第三方浏览器工具，与 mycomic.com 无隶属关系。漫画内容的版权归原作者及权利方所有，请遵守当地法律法规与网站使用条款。"
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("链接")
                        .font(.headline)
                    Link("访问 mycomic.com", destination: Site.home)
                        .font(.subheadline)
                }

                Text("© \(Calendar.current.component(.year, from: Date())) MyComic Client")
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
