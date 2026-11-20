//
//  RemoteImageView.swift
//  MyComic
//

import SwiftUI
import UIKit

struct RemoteImageView: View {
    let urlString: String
    var maxPixelSize: CGFloat = 1200
    var contentMode: ContentMode = .fill

    @StateObject private var loader = RemoteImageLoader()

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemBackground))

            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if loader.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .clipped()
        .task(id: urlString) {
            loader.load(url: URL(string: urlString), maxPixelSize: maxPixelSize)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}
