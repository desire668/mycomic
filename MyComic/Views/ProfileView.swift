//
//  ProfileView.swift
//  MyComic
//
//  Native "我的" hub. Every entry links to a page that exists on the website,
//  plus the native settings and about screens.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var network: NetworkMonitor
    var onDataCleared: () -> Void

    @State private var destination: WebDestination?

    var body: some View {
        NavigationView {
            List {
                headerSection
                websiteSection
                appSection
                footerSection
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $destination) { item in
                WebPageSheet(destination: item)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 14) {
                brandMark
                VStack(alignment: .leading, spacing: 4) {
                    Text("MyComic")
                        .font(.headline)
                    Text("版本 \(AppInfo.displayVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(network.isConnected ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(network.isConnected ? "网络正常" : "网络未连接")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    private var websiteSection: some View {
        Section(header: Text("网站功能")) {
            linkRow(title: "观看记录", icon: "clock.arrow.circlepath", url: Site.records)
            linkRow(title: "漫画排行", icon: "chart.bar", url: Site.ranking)
            linkRow(title: "最新上架", icon: "sparkles", url: Site.latest)
            linkRow(title: "我的收藏", icon: "bookmark", url: Site.bookmarks)
        }
    }

    private var appSection: some View {
        Section(header: Text("应用")) {
            NavigationLink(destination: SettingsView(network: network, onDataCleared: onDataCleared)) {
                Label("设置", systemImage: "gearshape")
            }
            NavigationLink(destination: AboutView()) {
                Label("关于 MyComic", systemImage: "info.circle")
            }
        }
    }

    private var footerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("内容由 mycomic.com 提供")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("本应用为第三方浏览器客户端，不修改、不绕过网站的登录、付费与版权保护机制。")
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Components

    private var brandMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                .frame(width: 54, height: 54)
            Text("M")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func linkRow(title: String, icon: String, url: URL) -> some View {
        Button {
            destination = WebDestination(title: title, url: url)
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
