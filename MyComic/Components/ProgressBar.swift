//
//  ProgressBar.swift
//  MyComic
//
//  Safari-style thin page-load progress indicator.
//

import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 2

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.clear
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * CGFloat(clamped), height: height)
                    .opacity(clamped > 0 && clamped < 1 ? 1 : 0)
                    .animation(.linear(duration: 0.2), value: clamped)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct ProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ProgressBar(progress: 0.35)
            ProgressBar(progress: 1)
        }
        .padding()
    }
}
