//
//  WebTab.swift
//  MyComic
//
//  The five root destinations of the app. Every web tab maps to a page that
//  actually exists on https://mycomic.com/cn — no invented features.
//

import Foundation

enum WebTab: String, CaseIterable, Identifiable {
    case home
    case catalog
    case search
    case bookmarks
    case profile

    var id: String { rawValue }

    /// Title shown in the native bottom bar.
    var title: String {
        switch self {
        case .home: return "首页"
        case .catalog: return "分类"
        case .search: return "搜索"
        case .bookmarks: return "书架"
        case .profile: return "我的"
        }
    }

    /// SF Symbol used in the native bottom bar.
    var iconName: String {
        switch self {
        case .home: return "house"
        case .catalog: return "square.grid.2x2"
        case .search: return "magnifyingglass"
        case .bookmarks: return "bookmark"
        case .profile: return "person"
        }
    }

    var selectedIconName: String {
        switch self {
        case .home: return "house.fill"
        case .catalog: return "square.grid.2x2.fill"
        case .search: return "magnifyingglass"
        case .bookmarks: return "bookmark.fill"
        case .profile: return "person.fill"
        }
    }

    /// Search loads its results only after the user submits a query.
    var initialURL: URL? {
        switch self {
        case .home: return Site.home
        case .catalog: return Site.catalog
        case .bookmarks: return Site.bookmarks
        case .search, .profile: return nil
        }
    }

    var navigationTitle: String {
        switch self {
        case .home: return "MyComic"
        case .catalog: return "漫画资料库"
        case .search: return "搜索"
        case .bookmarks: return "我的收藏"
        case .profile: return "我的"
        }
    }
}

/// Centralised list of the real routes on the target site.
enum Site {
    static let host = "mycomic.com"
    static let baseURLString = "https://mycomic.com/cn"

    static let home = URL(string: baseURLString)!
    static let catalog = URL(string: "https://mycomic.com/cn/comics")!
    static let bookmarks = URL(string: "https://mycomic.com/cn/bookmarks")!
    static let ranking = URL(string: "https://mycomic.com/cn/rank")!
    static let records = URL(string: "https://mycomic.com/cn/records")!
    static let latest = URL(string: "https://mycomic.com/cn/comics?sort=-update")!

    /// The site's own search is a GET request on the catalog page.
    static func searchURL(for keyword: String) -> URL? {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(string: "https://mycomic.com/cn/comics")
        components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        return components?.url
    }

    /// Returns true for the comic site itself (and its subdomains).
    static func isInternal(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == Site.host || host.hasSuffix(".\(Site.host)")
    }
}
