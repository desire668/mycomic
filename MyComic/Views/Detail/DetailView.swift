//
//  DetailView.swift
//  MyComic
//

import SwiftUI

struct DetailView: View {
    @StateObject private var viewModel: DetailViewModel
    @EnvironmentObject private var session: SessionViewModel
    @State private var summaryExpanded = false

    init(comicId: String, title: String, coverURLString: String) {
        _viewModel = StateObject(wrappedValue: DetailViewModel(
            comicId: comicId,
            title: title,
            coverURLString: coverURLString
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let detail = viewModel.detail {
                    header(detail)
                    actionButtons(detail)
                    summarySection(detail)
                    chapterSection(detail)
                } else if let error = viewModel.error {
                    ErrorStateView(error: error, onRetry: {
                        viewModel.reload()
                    }, onVerify: {
                        session.presentVerification { viewModel.reload() }
                    })
                    .frame(minHeight: 420)
                } else {
                    loadingState
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .navigationTitle(viewModel.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadIfNeeded()
            viewModel.refreshShelfState()
        }
    }

    // MARK: - Header

    private func header(_ detail: ComicDetail) -> some View {
        HStack(alignment: .top, spacing: 14) {
            coverView(detail.coverURLString)
                .frame(width: 108, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(detail.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)

                if let author = detail.author, !author.isEmpty {
                    Text("作者：\(author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    if let status = detail.status, !status.isEmpty {
                        Text(status)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(status.contains("完结") ? Color.gray.opacity(0.18) : Color.green.opacity(0.16))
                            .foregroundColor(status.contains("完结") ? .secondary : .green)
                            .clipShape(Capsule())
                    }
                    if let region = detail.region, !region.isEmpty {
                        Text(region)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text("共 \(detail.chapterCount) 话")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if !detail.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(detail.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func coverView(_ urlString: String) -> some View {
        if urlString.isEmpty {
            ZStack {
                LinearGradient(colors: [Color.orange.opacity(0.45), Color.red.opacity(0.35)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                Text(String(viewModel.displayTitle.prefix(1)))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
        } else {
            RemoteImageView(urlString: urlString, maxPixelSize: 700)
        }
    }

    // MARK: - Actions

    private func actionButtons(_ detail: ComicDetail) -> some View {
        HStack(spacing: 12) {
            NavigationLink(destination: ReaderView(route: readingRoute(detail))) {
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                    Text(viewModel.canContinue ? "继续阅读" : "开始阅读")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(detail.chapters.isEmpty)

            Button {
                viewModel.toggleShelf()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isOnShelf ? "checkmark.circle.fill" : "plus.circle")
                    Text(viewModel.isOnShelf ? "已在书架" : "加入书架")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func readingRoute(_ detail: ComicDetail) -> ReaderRoute {
        if let record = viewModel.lastRecord {
            return ReaderRoute(
                comicId: detail.id,
                comicTitle: detail.title,
                coverURLString: detail.coverURLString,
                chapterId: record.chapterId,
                chapterTitle: record.chapterTitle
            )
        }
        // The site lists chapters newest-first, so the oldest chapter is last.
        let chapter = detail.chapters.last
        return ReaderRoute(
            comicId: detail.id,
            comicTitle: detail.title,
            coverURLString: detail.coverURLString,
            chapterId: chapter?.id ?? "",
            chapterTitle: chapter?.title ?? ""
        )
    }

    // MARK: - Summary

    private func summarySection(_ detail: ComicDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)

            if let summary = detail.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(summaryExpanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)

                Button(summaryExpanded ? "收起" : "展开") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        summaryExpanded.toggle()
                    }
                }
                .font(.caption)
                .foregroundColor(.orange)
            } else {
                Text("站点未提供简介。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Chapters

    private func chapterSection(_ detail: ComicDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("章节列表")
                    .font(.headline)
                Text("(\(detail.chapterCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !detail.chapters.isEmpty {
                    Button {
                        viewModel.chaptersAscending.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(viewModel.chaptersAscending ? "正序" : "倒序")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
            }

            if detail.chapters.isEmpty {
                Text("未能解析到章节列表，页面结构可能已更新。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(viewModel.orderedChapters) { chapter in
                        NavigationLink(destination: ReaderView(route: ReaderRoute(
                            comicId: detail.id,
                            comicTitle: detail.title,
                            coverURLString: detail.coverURLString,
                            chapterId: chapter.id,
                            chapterTitle: chapter.title
                        ))) {
                            Text(chapter.title)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在加载漫画详情…")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}
