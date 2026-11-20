//
//  RankView.swift
//  MyComic
//

import SwiftUI

struct RankView: View {
    @StateObject private var viewModel = RankViewModel()
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("榜单", selection: $viewModel.board) {
                    ForEach(RankBoard.allCases) { board in
                        Text(board.title).tag(board)
                    }
                }
                .pickerStyle(.segmented)

                Text("排行榜由站点提供，仅包含排名、作者、最新章节与评分，页面本身不提供封面与阅读量数据。")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .navigationTitle("漫画排行")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.error, viewModel.entries.isEmpty {
            ErrorStateView(error: error, onRetry: {
                viewModel.load()
            }, onVerify: {
                session.presentVerification { viewModel.load() }
            })
            .frame(minHeight: 380)
        } else if viewModel.entries.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在获取排行榜…")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 340)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.entries) { entry in
                    NavigationLink(destination: DetailView(comicId: entry.comicId,
                                                           title: entry.title,
                                                           coverURLString: "")) {
                        rankRow(entry)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }

    private func rankRow(_ entry: RankEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(entry.rank)")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(entry.rank <= 3 ? .orange : .secondary)
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    if let author = entry.author {
                        Text(author)
                            .lineLimit(1)
                    }
                    if let chapter = entry.latestChapter {
                        Text(chapter)
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    if let updated = entry.updatedAt {
                        Text(updated)
                    }
                    if let score = entry.score {
                        Text("评分 \(score)")
                    }
                }
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
                .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
