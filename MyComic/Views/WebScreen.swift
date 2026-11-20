//
//  WebScreen.swift
//  MyComic
//
//  A complete web tab: native header, progress bar, the web view itself and
//  the full-screen reading mode for chapter pages.
//

import SwiftUI
import UIKit

struct WebScreen: View {
    @ObservedObject var model: WebViewModel
    @Binding var immersive: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !immersive {
                HeaderBar(model: model, immersive: $immersive)
                ProgressBar(progress: model.progress)
            }

            ZStack(alignment: .bottom) {
                WebContentView(model: model)
                if immersive {
                    exitFullScreenButton
                }
            }
        }
        .onAppear {
            model.startIfNeeded()
        }
        .onChange(of: model.isReaderPage) { isReader in
            if !isReader && immersive {
                withAnimation(.easeInOut(duration: 0.2)) {
                    immersive = false
                }
            }
        }
    }

    private var exitFullScreenButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                immersive = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 13, weight: .semibold))
                Text("退出全屏")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.black.opacity(0.55))
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .padding(.bottom, 18)
        .accessibilityLabel("退出全屏阅读")
    }
}

/// Reusable web content area (web view + loading + error states).
struct WebContentView: View {
    @ObservedObject var model: WebViewModel

    var body: some View {
        ZStack {
            WebView(model: model)

            if let error = model.error {
                ErrorStateView(
                    error: error,
                    onRetry: { model.retry() },
                    onOpenInBrowser: openInBrowser
                )
                .transition(.opacity)
            } else if model.isLoading && !model.hasFinishedFirstLoad {
                LoadingView()
            }
        }
        .onAppear {
            model.startIfNeeded()
        }
    }

    private func openInBrowser() {
        let url = model.currentURL ?? model.tab?.initialURL ?? Site.home
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
