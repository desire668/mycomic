//
//  SearchView.swift
//  MyComic
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchField
                    sortMenu
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("输入漫画名称，如 one", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit {
                    viewModel.submit()
                }
                .onChange(of: viewModel.query) { _ in
                    viewModel.queryChanged()
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.queryChanged()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var sortMenu: some View {
        HStack {
            Text("排序")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Menu {
                ForEach(SortOption.allCases) { option in
                    Button(option.title) {
                        viewModel.changeSort(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.sort.title)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.trimmedQuery.isEmpty {
            historySection
        } else if let error = viewModel.error, viewModel.results.isEmpty {
            ErrorStateView(error: error, onRetry: {
                viewModel.submit()
            }, onVerify: {
                session.presentVerification { viewModel.submit() }
            })
            .frame(minHeight: 360)
        } else if viewModel.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在搜索…")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else if viewModel.results.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(.secondary)
                Text("没有找到相关漫画")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("找到 \(viewModel.results.count) 部漫画")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ComicGrid(comics: viewModel.results)

                if viewModel.isLoadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, 10)
                } else if viewModel.canLoadMore {
                    Button {
                        viewModel.loadMore()
                    } label: {
                        Text("加载更多")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("搜索历史")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if !viewModel.history.isEmpty {
                    Button("清空") {
                        viewModel.clearHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            if viewModel.history.isEmpty {
                Text("暂无搜索历史，输入关键词开始搜索。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8, alignment: .leading)],
                          alignment: .leading,
                          spacing: 8) {
                    ForEach(viewModel.history, id: \.self) { keyword in
                        HStack(spacing: 6) {
                            Button {
                                viewModel.searchFromHistory(keyword)
                            } label: {
                                Text(keyword)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            Button {
                                viewModel.removeHistory(keyword)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
}
