//
//  HomeViewModel.swift
//  MyComic
//

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var feed: HomeFeed?
    @Published private(set) var isLoading = false
    @Published private(set) var error: AppError?

    private let repository: ComicRepository
    private var loadTask: Task<Void, Never>?

    init(repository: ComicRepository = .shared) {
        self.repository = repository
    }

    func loadIfNeeded() {
        guard feed == nil, !isLoading else { return }
        reload()
    }

    func reload() {
        loadTask?.cancel()
        isLoading = true
        error = nil
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.repository.homeFeed()
                if Task.isCancelled { return }
                self.feed = result
                self.error = nil
            } catch let appError as AppError {
                if appError.isCancelled { return }
                self.error = appError
            } catch {
                self.error = .other(error.localizedDescription)
            }
            self.isLoading = false
        }
    }
}
