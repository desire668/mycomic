//
//  ContentView.swift
//  MyComic
//
//  Root container: native tab bar, splash handling and shared web sessions.
//  Each web tab owns exactly one WKWebView instance for the whole app lifetime.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var homeModel = WebViewModel(tab: .home)
    @StateObject private var catalogModel = WebViewModel(tab: .catalog)
    @StateObject private var bookmarksModel = WebViewModel(tab: .bookmarks)
    @StateObject private var searchTab = SearchTabModel()

    @ObservedObject private var network = NetworkMonitor.shared

    @State private var selection: WebTab = .home
    @State private var immersive = false
    @State private var showLaunch = true
    @State private var splashTimer: DispatchWorkItem?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                OfflineBanner(isOffline: !network.isConnected)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !immersive {
                    BottomTabBar(selection: $selection)
                        .transition(.move(edge: .bottom))
                }
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())

            if showLaunch {
                LaunchView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .statusBar(hidden: immersive)
        .onAppear(perform: scheduleSplashDismissal)
        .onChange(of: homeModel.hasFinishedFirstLoad) { finished in
            if finished { dismissLaunch() }
        }
        .onChange(of: homeModel.error) { error in
            if error != nil { dismissLaunch() }
        }
        .onChange(of: selection) { _ in
            if immersive {
                withAnimation(.easeInOut(duration: 0.2)) {
                    immersive = false
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .home:
            WebScreen(model: homeModel, immersive: $immersive)
        case .catalog:
            WebScreen(model: catalogModel, immersive: $immersive)
        case .bookmarks:
            WebScreen(model: bookmarksModel, immersive: $immersive)
        case .search:
            SearchView(tabModel: searchTab, network: network)
        case .profile:
            ProfileView(network: network, onDataCleared: reloadLoadedPages)
        }
    }

    // MARK: - Splash

    private func scheduleSplashDismissal() {
        let work = DispatchWorkItem { dismissLaunch() }
        splashTimer = work
        // Never keep the splash for longer than 3 seconds, even on slow networks.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    private func dismissLaunch() {
        splashTimer?.cancel()
        splashTimer = nil
        guard showLaunch else { return }
        withAnimation(.easeOut(duration: 0.35)) {
            showLaunch = false
        }
    }

    // MARK: - Data

    private func reloadLoadedPages() {
        homeModel.reloadAfterDataChange()
        catalogModel.reloadAfterDataChange()
        bookmarksModel.reloadAfterDataChange()
        searchTab.reloadAfterDataChange()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
