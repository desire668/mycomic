//
//  BrowserSession.swift
//  MyComic
//
//  Owns the shared WKWebViewConfiguration so that every tab uses the same
//  process pool, cookie store and cache. This keeps a single login session
//  across all tabs and avoids creating duplicated web processes.
//

import Foundation
import WebKit

enum BrowserSession {
    /// Persistent data store: cookies and local storage survive app restarts,
    /// which preserves the site's own session/login mechanism.
    static let dataStore: WKWebsiteDataStore = .default()

    static let configuration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // The site's pages are responsive; keep the standard mobile viewport.
        configuration.suppressesIncrementalRendering = false
        configuration.applicationNameForUserAgent = "MyComic/1.0"
        return configuration
    }()

    static func makeWebView() -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.delaysContentTouches = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        return webView
    }

    // MARK: - Data management

    private static var cacheTypes: Set<String> {
        [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeOfflineWebApplicationCache
        ]
    }

    private static var cookieTypes: Set<String> {
        [
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeWebSQLDatabases
        ]
    }

    static func clearCache(completion: @escaping () -> Void) {
        dataStore.removeData(ofTypes: cacheTypes, modifiedSince: .distantPast) {
            DispatchQueue.main.async { completion() }
        }
    }

    static func clearCookies(completion: @escaping () -> Void) {
        let group = DispatchGroup()
        group.enter()
        dataStore.removeData(ofTypes: cookieTypes, modifiedSince: .distantPast) {
            group.leave()
        }
        group.enter()
        dataStore.httpCookieStore.getAllCookies { cookies in
            let cookieGroup = DispatchGroup()
            cookies.forEach { cookie in
                cookieGroup.enter()
                dataStore.httpCookieStore.delete(cookie) { cookieGroup.leave() }
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
            cookieGroup.notify(queue: .global()) { group.leave() }
        }
        group.notify(queue: .main) { completion() }
    }

    static func clearEverything(completion: @escaping () -> Void) {
        let allTypes = cacheTypes.union(cookieTypes).union([WKWebsiteDataTypeFetchCache])
        dataStore.removeData(ofTypes: allTypes, modifiedSince: .distantPast) {
            DispatchQueue.main.async { completion() }
        }
    }
}
