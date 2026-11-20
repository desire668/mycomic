//
//  ProfileView.swift
//  MyComic
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var session: SessionViewModel
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var network: NetworkMonitor
    @State private var showLogin = false
    @State private var isCheckingAccess = false

    var body: some View {
        NavigationView {
            List {
                accountSection
                sessionSection
                localDataSection
                settingsSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                session.refreshStatus()
            }
            .sheet(isPresented: $showLogin) {
                LoginView(viewModel: viewModel)
                    .environmentObject(session)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section(header: Text("账号")) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loginStateTitle)
                        .font(.subheadline)
                    Text("收藏与阅读进度以本地书架为准")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if viewModel.isChecking {
                    ProgressView()
                }
            }

            Button {
                showLogin = true
            } label: {
                Label("登录 MyComic（实验性）", systemImage: "arrow.right.to.line")
            }

            Button {
                Task { await viewModel.checkLoginState() }
            } label: {
                Label("检测登录状态", systemImage: "checkmark.shield")
            }

            if let message = viewModel.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var sessionSection: some View {
        Section(header: Text("会话与 Cloudflare")) {
            statusRow(title: "Cloudflare 验证",
                      value: session.cookieStatus.clearanceDescription,
                      color: session.cookieStatus.hasClearance ? .green : .orange)

            statusRow(title: "站点 Cookie",
                      value: "\(session.cookieStatus.cookieCount) 个",
                      color: .secondary)

            statusRow(title: "网络",
                      value: network.statusDescription,
                      color: network.isConnected ? .green : .red)

            Button {
                session.presentVerification()
            } label: {
                Label("进行 Cloudflare 验证", systemImage: "hand.raised")
            }

            Button {
                Task {
                    isCheckingAccess = true
                    let result = await session.verifyAccess()
                    isCheckingAccess = false
                    if case .failure = result {
                        showLogin = false
                    }
                }
            } label: {
                HStack {
                    Label("重新检测站点访问", systemImage: "antenna.radiowaves.left.and.right")
                    if isCheckingAccess {
                        Spacer()
                        ProgressView()
                    }
                }
            }

            if let last = session.lastVerificationMessage {
                Text(last)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var localDataSection: some View {
        Section(header: Text("本地数据")) {
            HStack {
                Label("书架", systemImage: "books.vertical")
                Spacer()
                Text("\(library.shelf.count) 部")
                    .foregroundColor(.secondary)
            }
            HStack {
                Label("阅读历史", systemImage: "clock.arrow.circlepath")
                Spacer()
                Text("\(library.history.count) 条")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var settingsSection: some View {
        Section {
            NavigationLink(destination: SettingsView()) {
                Label("设置", systemImage: "gearshape")
            }
        }
    }

    private var aboutSection: some View {
        Section(header: Text("关于")) {
            HStack {
                Text("版本")
                Spacer()
                Text(AppInfo.displayVersion)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("数据来源")
                Spacer()
                Text("mycomic.com")
                    .foregroundColor(.secondary)
            }
            Text("本应用为第三方非官方客户端，所有漫画内容与版权归 mycomic.com 及相关权利人所有。应用本身不存储、不托管任何漫画内容。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var loginStateTitle: String {
        switch viewModel.loginState {
        case .signedIn: return "已登录站点账号"
        case .signedOut: return "未登录站点账号"
        case .unknown: return "登录状态未知"
        }
    }

    private func statusRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .font(.subheadline)
        }
    }
}

// MARK: - Login sheet

struct LoginView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("登录 MyComic")) {
                    TextField("邮箱", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                    SecureField("密码", text: $viewModel.password)
                }

                Section(footer: Text("实验性功能：站点登录表单为 Laravel POST /cn/login，登录结果会如实显示。收藏同步未实现，书架仍保存在本机。")) {
                    Button {
                        Task { await viewModel.login() }
                    } label: {
                        HStack {
                            Text("登录")
                            if viewModel.isLoggingIn {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isLoggingIn)
                }

                if let message = viewModel.message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("进行 Cloudflare 验证") {
                        session.presentVerification()
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
