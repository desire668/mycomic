//
//  ErrorStateView.swift
//  MyComic
//
//  Native error screen with retry, shown when the site cannot be reached.
//

import SwiftUI

struct ErrorStateView: View {
    let error: WebLoadError
    let onRetry: () -> Void
    let onOpenInBrowser: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(error.title)
                    .font(.headline)
                Text(error.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Button(action: onRetry) {
                    Text("重新加载")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: onOpenInBrowser) {
                    Text("在 Safari 中打开")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }

    private var iconName: String {
        switch error {
        case .offline: return "wifi.slash"
        case .timeout: return "clock"
        case .hostUnavailable: return "antenna.radiowaves.left.and.right.slash"
        case .server: return "exclamationmark.icloud"
        case .insecure: return "lock.slash"
        case .other: return "exclamationmark.triangle"
        }
    }
}

struct ErrorStateView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorStateView(error: .offline, onRetry: {}, onOpenInBrowser: {})
    }
}
