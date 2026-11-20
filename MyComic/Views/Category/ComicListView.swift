//
//  ComicListView.swift
//  MyComic
//
//  Generic paginated comic list (home "more" screens).
//

import SwiftUI

struct ComicListView: View {
    @StateObject private var viewModel: ComicListViewModel
    @EnvironmentObject private var session: SessionViewModel

    init(title: String, sort: SortOption) {
        _viewModel = StateObject(wrappedValue: ComicListViewModel(title: title, sort: sort))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = viewModel.error, viewModel.comics.isEmpty {
                    ErrorStateView(error: error, onRetry: {
                        viewModel.reload()
                    }, onVerify: {
                        session.presentVerification { viewModel.reload() }
                    })
                    .frame(minHeight: 420)
                } else if viewModel.comics.isEmpty {
                    if viewModel.isLoading {
                        loadingState
                    } else {
                        emptyState
                    }
                } else {
                    if let error = viewModel.error {
                        inlineError(error)
                    }

                    ComicGrid(comics: viewModel.comics)

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    } else if !viewModel.hasMore {
                        Text("已经到底了")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.reload()
        }
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在加载…")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
            Text("没有找到漫画")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func inlineError(_ error: AppError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("重试") { viewModel.reload() }
                .font(.caption)
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
