//
//  ErrorStateView.swift
//  MyComic
//

import SwiftUI

struct ErrorStateView: View {
    let error: AppError
    var onRetry: () -> Void
    var onVerify: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 46, weight: .light))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text(error.localizedDescription)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 32)

            VStack(spacing: 10) {
                if error.isCloudflare, let onVerify = onVerify {
                    Button(action: onVerify) {
                        Text("进行 Cloudflare 验证")
                            .font(.headline)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }

                Button(action: onRetry) {
                    Text(error.isCloudflare ? "验证后重试" : "重新加载")
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 12)
                        .background(error.isCloudflare && onVerify != nil ? Color(.secondarySystemBackground) : Color.accentColor)
                        .foregroundColor(error.isCloudflare && onVerify != nil ? .primary : .white)
                        .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var iconName: String {
        switch error {
        case .offline: return "wifi.slash"
        case .timedOut: return "clock"
        case .cloudflareRequired: return "hand.raised"
        case .http(403): return "lock.slash"
        case .http(404): return "questionmark.folder"
        case .http: return "exclamationmark.icloud"
        case .parse: return "doc.text.magnifyingglass"
        case .cancelled: return "xmark.circle"
        case .invalidURL: return "link.badge.plus"
        case .other: return "exclamationmark.triangle"
        }
    }
}
