//
//  SettingsView.swift
//  MyComic
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var session: SessionViewModel
    @EnvironmentObject private var network: NetworkMonitor

    @State private var imageCacheText = "计算中…"
    @State private var message: String?
    @State private var showClearCookiesConfirm = false

    var body: some View {
        Form {
            readingSection
            cacheSection
            sessionSection
            networkSection
            aboutSection
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshCacheSize()
            session.refreshStatus()
        }
    }

    // MARK: - Reading

    private var readingSection: some View {
        Section(header: Text("阅读")) {
            Picker("阅读模式", selection: $settings.readingMode) {
                ForEach(ReadingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(settings.readingMode.subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)

            Toggle("自动加载下一章", isOn: $settings.autoLoadNextChapter)
            Toggle("阅读时屏幕常亮", isOn: $settings.keepScreenAwake)
            Toggle("保存阅读历史", isOn: $settings.saveReadingHistory)
        }
    }

    // MARK: - Cache

    private var cacheSection: some View {
        Section(header: Text("缓存"), footer: Text("漫画图片缓存在本机，清理后需要重新下载。")) {
            HStack {
                Text("图片缓存")
                Spacer()
                Text(imageCacheText)
                    .foregroundColor(.secondary)
            }

            Button("清理图片缓存") {
                ImagePipeline.shared.clearCache {
                    refreshCacheSize()
                    message = "已清理图片缓存。"
                }
            }

            Button("清理网络缓存") {
                URLCache.shared.removeAllCachedResponses()
                message = "已清理 URL 网络缓存。"
            }
        }
    }

    // MARK: - Site session

    private var sessionSection: some View {
        Section(header: Text("站点会话"), footer: Text("清除 Cookie 会同时清除网站登录状态与 Cloudflare 验证状态。")) {
            HStack {
                Text("Cloudflare 验证")
                Spacer()
                Text(session.cookieStatus.clearanceDescription)
                    .foregroundColor(session.cookieStatus.hasClearance ? .green : .orange)
            }

            HStack {
                Text("站点 Cookie")
                Spacer()
                Text("\(session.cookieStatus.cookieCount) 个")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("请求 User-Agent")
                Spacer()
                Text(session.cookieStatus.userAgent == UserAgentProvider.defaultAgent ? "默认" : "已验证页面")
                    .foregroundColor(.secondary)
            }

            Button {
                session.presentVerification()
            } label: {
                Label("进行 Cloudflare 验证", systemImage: "hand.raised")
            }

            Button {
                Task { _ = await session.verifyAccess() }
            } label: {
                HStack {
                    Label("检测站点访问", systemImage: "antenna.radiowaves.left.and.right")
                    if session.isVerifying {
                        Spacer()
                        ProgressView()
                    }
                }
            }

            Button {
                showClearCookiesConfirm = true
            } label: {
                Label("清除站点 Cookie", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Network

    private var networkSection: some View {
        Section(header: Text("网络")) {
            HStack {
                Text("连接状态")
                Spacer()
                Text(network.statusDescription)
                    .foregroundColor(network.isConnected ? .green : .red)
            }
            HStack {
                Text("连接类型")
                Spacer()
                Text(network.connectionTypeDescription)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section(header: Text("关于"), footer: Text("本应用为第三方非官方客户端，漫画内容与版权归 mycomic.com 及相关权利人所有，应用本身不存储、不托管任何漫画内容。")) {
            HStack {
                Text("版本")
                Spacer()
                Text(AppInfo.displayVersion)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Bundle Identifier")
                Spacer()
                Text(AppInfo.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let url = URL(string: "https://mycomic.com/cn") {
                Link("访问 mycomic.com", destination: url)
            }
            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .alert(isPresented: $showClearCookiesConfirm) {
            Alert(
                title: Text("清除站点 Cookie？"),
                message: Text("这会退出网站登录并清除 Cloudflare 验证状态，需要重新验证后才能继续访问。"),
                primaryButton: .destructive(Text("清除")) {
                    UserAgentProvider.reset()
                    CookieManager.clear {
                        session.refreshStatus()
                        message = "已清除站点 Cookie。"
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - Helpers

    private func refreshCacheSize() {
        imageCacheText = "计算中…"
        DispatchQueue.global(qos: .utility).async {
            let size = ImagePipeline.diskCacheSize()
            let text = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            DispatchQueue.main.async {
                imageCacheText = text
            }
        }
    }
}
