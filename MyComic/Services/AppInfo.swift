//
//  AppInfo.swift
//  MyComic
//

import Foundation

enum AppInfo {
    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    static var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }

    static var displayVersion: String {
        "\(version) (\(build))"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.mycomic.app"
    }
}
