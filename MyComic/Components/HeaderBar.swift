//
//  HeaderBar.swift
//  MyComic
//
//  Native navigation bar for a web tab: back, forward, page title, reload and
//  the full-screen reading toggle.
//

import SwiftUI

struct HeaderBar: View {
    @ObservedObject var model: WebViewModel
    @Binding var immersive: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                navButton(systemName: "chevron.left", enabled: model.canGoBack, label: "后退") {
                    model.goBack()
                }

                navButton(systemName: "chevron.right", enabled: model.canGoForward, label: "前进") {
                    model.goForward()
                }

                Spacer(minLength: 6)

                VStack(spacing: 1) {
                    Text(model.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(hostText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 6)

                if model.isReaderPage {
                    navButton(systemName: "arrow.up.left.and.arrow.down.right", enabled: true, label: "全屏阅读") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            immersive = true
                        }
                    }
                }

                if model.isLoading {
                    navButton(systemName: "xmark", enabled: true, label: "停止加载") {
                        model.stopLoading()
                    }
                } else {
                    navButton(systemName: "arrow.clockwise", enabled: true, label: "刷新") {
                        model.reload()
                    }
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 46)

            Divider()
        }
        .background(barBackground)
    }

    private var hostText: String {
        guard let url = model.currentURL, let host = url.host else {
            return "mycomic.com"
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private var barBackground: some View {
        Color(UIColor.systemBackground)
            .ignoresSafeArea(edges: .top)
    }

    private func navButton(systemName: String,
                           enabled: Bool,
                           label: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.28)
        .accessibilityLabel(label)
    }
}
