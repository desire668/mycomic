//
//  WebView.swift
//  MyComic
//
//  Thin UIViewRepresentable bridge. It never creates a new WKWebView: the
//  instance owned by WebViewModel is reused across SwiftUI updates.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let model: WebViewModel

    func makeUIView(context: Context) -> WKWebView {
        model.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Navigation is driven by WebViewModel.
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        // The web view is owned by the model and stays alive for the tab's
        // lifetime; nothing to tear down here.
    }
}
