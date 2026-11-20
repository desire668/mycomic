//
//  OfflineBanner.swift
//  MyComic
//
//  Compact banner displayed whenever NWPathMonitor reports no connectivity.
//

import SwiftUI

struct OfflineBanner: View {
    let isOffline: Bool

    var body: some View {
        if isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                Text("当前无网络连接，请检查 Wi-Fi 或蜂窝网络")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.orange.opacity(0.18))
            .foregroundColor(Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel("当前无网络连接")
        }
    }
}
