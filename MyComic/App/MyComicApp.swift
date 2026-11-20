//
//  MyComicApp.swift
//  MyComic
//

import SwiftUI
import UIKit

@main
struct MyComicApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var library = LibraryStore.shared
    @StateObject private var session = SessionViewModel()
    @StateObject private var network = NetworkMonitor.shared

    init() {
        Self.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(settings)
                .environmentObject(library)
                .environmentObject(session)
                .environmentObject(network)
                .accentColor(.orange)
        }
    }

    private static func configureAppearance() {
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar

        let tabBar = UITabBarAppearance()
        tabBar.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBar
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBar
        }
    }
}
