//
//  ComicCard.swift
//  MyComic
//

import SwiftUI

struct ComicCard: View {
    let comic: Comic

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImageView(urlString: comic.coverURLString, maxPixelSize: 900)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )

            Text(comic.title)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(.primary)

            if let latest = comic.latestChapter, !latest.isEmpty {
                Text(latest)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

struct ComicGrid: View {
    let comics: [Comic]
    var minimumWidth: CGFloat = 104

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minimumWidth, maximum: 180), spacing: 12, alignment: .top)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ForEach(comics) { comic in
                NavigationLink(destination: DetailView(comicId: comic.id,
                                                       title: comic.title,
                                                       coverURLString: comic.coverURLString)) {
                    ComicCard(comic: comic)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var moreDestination: AnyView?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let moreDestination = moreDestination {
                NavigationLink(destination: moreDestination) {
                    HStack(spacing: 2) {
                        Text("更多")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}
