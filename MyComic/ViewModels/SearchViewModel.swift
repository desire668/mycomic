//
//  SearchViewModel.swift
//  MyComic
//

import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: [Comic] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: AppError?
    @Published private(set) var history: [String] = []
    @Published var sort: SortOption = .newest

    private let repository: ComicRepository
    private let historyKey = "mycomic.search.history"
    private var searchTask: Task<Void, Never>?
    private var page = 0
    private var maxPage = 1
    private var activeQuery = ""

    init(repository: ComicRepository = .shared) {
        self.repository = repository
        history = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
    }

    var hasMore: Bool { page < maxPage }
    var canLoadMore: Bool { hasMore && !activeQuery.isEmpty }
    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - Input

    func queryChanged() {
        searchTask?.cancel()
        let text = trimmedQuery
        guard !text.isEmpty else {
            results = []
            error = nil
            isLoading = false
            activeQuery = ""
            return
        }

        searchTask = Task { [weak self] in
            // Simple debounce so we do not hit the site on every keystroke.
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard let self = self, !Task.isCancelled else { return }
            self.performSearch(text: text)
        }
    }

    func submit() {
        searchTask?.cancel()
        let text = trimmedQuery
        guard !text.isEmpty else { return }
        saveHistory(text)
        performSearch(text: text)
    }

    func searchFromHistory(_ keyword: String) {
        query = keyword
        submit()
    }

    func changeSort(_ newSort: SortOption) {
        guard newSort != sort else { return }
        sort = newSort
        guard !activeQuery.isEmpty else { return }
        performSearch(text: activeQuery)
    }

    // MARK: - Loading

    private func performSearch(text: String) {
        isLoading = true
        error = nil
        results = []
        page = 0
        maxPage = 1
        activeQuery = text
        saveHistory(text)

        searchTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.repository.search(query: text, sort: self.sort, page: 1)
                if Task.isCancelled { return }
                self.results = result.comics
                self.page = result.page
                self.maxPage = result.maxPage
            } catch let appError as AppError {
                if !appError.isCancelled {
                    self.error = appError
                }
            } catch {
                self.error = .other(error.localizedDescription)
            }
            self.isLoading = false
        }
    }

    func loadMoreIfNeeded(currentItem: Comic) {
        guard canLoadMore, !isLoading, !isLoadingMore,
              let index = results.firstIndex(of: currentItem),
              index >= results.count - 4 else { return }
        loadMore()
    }

    func loadMore() {
        guard canLoadMore, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        let text = activeQuery
        let nextPage = page + 1

        searchTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.repository.search(query: text, sort: self.sort, page: nextPage)
                if Task.isCancelled { return }
                let existing = Set(self.results.map { $0.id })
                self.results.append(contentsOf: result.comics.filter { !existing.contains($0.id) })
                self.page = result.page
                self.maxPage = result.maxPage
            } catch let appError as AppError {
                if !appError.isCancelled { self.error = appError }
            } catch {
                self.error = .other(error.localizedDescription)
            }
            self.isLoadingMore = false
        }
    }

    // MARK: - History

    func removeHistory(_ keyword: String) {
        history.removeAll { $0 == keyword }
        persistHistory()
    }

    func clearHistory() {
        history.removeAll()
        persistHistory()
    }

    private func saveHistory(_ keyword: String) {
        guard !keyword.isEmpty else { return }
        history.removeAll { $0 == keyword }
        history.insert(keyword, at: 0)
        if history.count > 20 {
            history = Array(history.prefix(20))
        }
        persistHistory()
    }

    private func persistHistory() {
        UserDefaults.standard.set(history, forKey: historyKey)
    }
}
