//
//  RootTabView.swift
//  MyComic
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var network: NetworkMonitor
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        VStack(spacing: 0) {
            OfflineBanner(isOffline: network.hasDeterminedStatus && !network.isConnected)

            TabView {
                HomeView()
                    .tabItem { Label("首页", systemImage: "house.fill") }

                CategoryView()
                    .tabItem { Label("分类", systemImage: "square.grid.2x2.fill") }

                SearchView()
                    .tabItem { Label("搜索", systemImage: "magnifyingglass") }

                ShelfView()
                    .tabItem { Label("书架", systemImage: "books.vertical.fill") }

                ProfileView()
                    .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
            }
        }
        .sheet(isPresented: $session.isPresentingVerification) {
            CloudflareVerifyView()
                .environmentObject(session)
        }
    }
}
