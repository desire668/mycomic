//
//  CategoryView.swift
//  MyComic
//

import SwiftUI

struct CategoryView: View {
    @StateObject private var viewModel = ComicListViewModel(title: "分类", sort: .newest)
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sortPicker
                    filterPanel
                    resultsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .navigationTitle("分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: RankView()) {
                        Image(systemName: "chart.bar.xaxis")
                    }
                }
            }
            .refreshable {
                viewModel.reload()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadIfNeeded()
            viewModel.loadFiltersIfNeeded()
        }
    }

    // MARK: - Sort

    private var sortPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("排序方式")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("排序", selection: Binding(
                get: { viewModel.sort },
                set: { viewModel.changeSort($0) }
            )) {
                ForEach(SortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Filters

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !viewModel.filterGroups.isEmpty {
                ForEach(viewModel.filterGroups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(group.options) { option in
                                    filterChip(option, in: group)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
            }

            HStack {
                Text(viewModel.selectedFilterSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.hasActiveFilters {
                    Button("清除筛选") {
                        viewModel.clearFilters()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
        }
    }

    private func filterChip(_ option: FilterOption, in group: FilterGroup) -> some View {
        let isSelected = viewModel.selectedFilters[group.key] == option.value
        return Button {
            viewModel.selectOption(option, in: group)
        } label: {
            Text(option.label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.orange : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        if let error = viewModel.error, viewModel.comics.isEmpty {
            ErrorStateView(error: error, onRetry: {
                viewModel.reload()
            }, onVerify: {
                session.presentVerification { viewModel.reload() }
            })
            .frame(minHeight: 360)
        } else if viewModel.comics.isEmpty {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在加载漫画…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.secondary)
                    Text("当前筛选条件下没有漫画")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ComicGrid(comics: viewModel.comics)

                if viewModel.isLoadingMore {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, 10)
                } else if viewModel.hasMore {
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
                } else {
                    Text("已经到底了")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }
}
