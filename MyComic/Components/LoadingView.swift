//
//  LoadingView.swift
//  MyComic
//
//  First-load indicator shown on top of the web view.
//

import SwiftUI

struct LoadingView: View {
    var message: String = "正在加载…"

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.1)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 28)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
            .padding(40)
            .previewLayout(.sizeThatFits)
    }
}
