//
//  ShelfView.swift
//  MyComic
//
//  Local shelf and reading history. This data is stored on device only.
//

import SwiftUI

struct ShelfView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: SettingsStore
    @State private var showClearHistoryConfirm = false
    @State private var readerRoute: ReaderRoute?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if library.shelf.isEmpty && library.history.isEmpty {
                        emptyState
                    } else {
                        shelfSection
                        historySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .navigationTitle("书架")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(isPresented: $showClearHistoryConfirm) {
            Alert(
                title: Text("清空阅读历史？"),
                message: Text("仅清除本机记录，不会影响网站数据。"),
                primaryButton: .destructive(Text("清空")) {
                    library.clearHistory()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .fullScreenCover(item: $readerRoute) { route in
            ReaderView(route: route)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("本地书架")
                .font(.title3)
                .fontWeight(.bold)
            Text("收藏与阅读进度仅保存在本机，站点没有公开的收藏接口。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.secondary)
            Text("书架还是空的")
                .font(.subheadline)
            Text("在漫画详情页点击「加入书架」即可收藏。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    @ViewBuilder
    private var shelfSection: some View {
        if !library.shelf.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "我的收藏", subtitle: "共 \(library.shelf.count) 部", moreDestination: nil)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 180), spacing: 12)],
                          alignment: .leading,
                          spacing: 18) {
                    ForEach(library.shelf) { comic in
                        NavigationLink(destination: DetailView(comicId: comic.id,
                                                               title: comic.title,
                                                               coverURLString: comic.coverURLString)) {
                            ComicCard(comic: comic)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button {
                                library.removeFromShelf(comicId: comic.id)
                            } label: {
                                Label("移出书架", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        if !library.history.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("阅读历史")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    Button("清空") {
                        showClearHistoryConfirm = true
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                ForEach(library.history) { record in
                    Button {
                        readerRoute = ReaderRoute(
                            comicId: record.comicId,
                            comicTitle: record.comicTitle,
                            coverURLString: record.coverURLString,
                            chapterId: record.chapterId,
                            chapterTitle: record.chapterTitle
                        )
                    } label: {
                        historyRow(record)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()
                }
            }
        }
    }

    private func historyRow(_ record: ReadingRecord) -> some View {
        HStack(spacing: 12) {
            RemoteImageView(urlString: record.coverURLString, maxPixelSize: 260)
                .frame(width: 48, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.comicTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(record.progressText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(relativeDate(record.updatedAt))
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabel))
            }

            Spacer()

            Button {
                library.removeHistory(comicId: record.comicId)
            } label: {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
