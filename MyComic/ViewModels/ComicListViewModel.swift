//
//  ComicListViewModel.swift
//  MyComic
//
//  Shared list logic for category browsing and home "more" screens.
//

import Foundation

@MainActor
final class ComicListViewModel: ObservableObject {
    @Published private(set) var comics: [Comic] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: AppError?
    @Published private(set) var filterGroups: [FilterGroup] = []
    @Published var selectedFilters: [String: String] = [:]
    @Published var sort: SortOption

    let title: String
    private let repository: ComicRepository
    private var page = 0
    private var maxPage = 1
    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?

    init(title: String, sort: SortOption, repository: ComicRepository = .shared) {
        self.title = title
        self.sort = sort
        self.repository = repository
    }

    var hasMore: Bool { page < maxPage }

    var hasActiveFilters: Bool { !selectedFilters.isEmpty }

    var selectedFilterSummary: String {
        guard !selectedFilters.isEmpty else { return "全部" }
        var labels: [String] = []
        for group in filterGroups {
            if let value = selectedFilters[group.key],
               let option = group.options.first(where: { $0.value == value }) {
                labels.append(option.label)
            }
        }
        return labels.isEmpty ? "已筛选" : labels.joined(separator: " · ")
    }

    func loadIfNeeded() {
        guard comics.isEmpty, !isLoading else { return }
        reload()
    }

    func reload() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        isLoading = true
        error = nil
        page = 0
        maxPage = 1

        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.repository.list(sort: self.sort, page: 1, filters: self.selectedFilters)
                if Task.isCancelled { return }
                self.comics = result.comics
                self.page = result.page
                self.maxPage = result.maxPage
            } catch let appError as AppError {
                if appError.isCancelled { return }
                self.error = appError
            } catch {
                self.error = .other(error.localizedDescription)
            }
            self.isLoading = false
        }
    }

    func loadMoreIfNeeded(currentItem: Comic) {
        guard let index = comics.firstIndex(of: currentItem) else { return }
        if index >= comics.count - 4 {
            loadMore()
        }
    }

    func loadMore() {
        guard !isLoading, !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        loadMoreTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.repository.list(sort: self.sort, page: self.page + 1, filters: self.selectedFilters)
                if Task.isCancelled { return }
                let existing = Set(self.comics.map { $0.id })
                let fresh = result.comics.filter { !existing.contains($0.id) }
                self.comics.append(contentsOf: fresh)
                self.page = result.page
                self.maxPage = result.maxPage
            } catch let appError as AppError {
                if !appError.isCancelled {
                    self.error = appError
                }
            } catch {
                self.error = .other(error.localizedDescription)
            }
            self.isLoadingMore = false
        }
    }

    func selectOption(_ option: FilterOption, in group: FilterGroup) {
        if selectedFilters[group.key] == option.value {
            selectedFilters[group.key] = nil
        } else {
            selectedFilters[group.key] = option.value
        }
        reload()
    }

    func clearFilters() {
        guard hasActiveFilters else { return }
        selectedFilters.removeAll()
        reload()
    }

    func changeSort(_ newSort: SortOption) {
        guard newSort != sort else { return }
        sort = newSort
        reload()
    }

    func loadFiltersIfNeeded() {
        guard filterGroups.isEmpty else { return }
        Task { [weak self] in
            guard let self = self else { return }
            if let groups = try? await self.repository.filterGroups() {
                self.filterGroups = groups
            }
        }
    }
}
