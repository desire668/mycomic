//
//  RankViewModel.swift
//  MyComic
//

import Foundation

@MainActor
final class RankViewModel: ObservableObject {
    @Published var board: RankBoard = .daily {
        didSet {
            if board != oldValue { load() }
        }
    }
    @Published private(set) var entries: [RankEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: AppError?

    private let repository: ComicRepository
    private var loadTask: Task<Void, Never>?

    init(repository: ComicRepository = .shared) {
        self.repository = repository
    }

    func loadIfNeeded() {
        guard entries.isEmpty, !isLoading else { return }
        load()
    }

    func load() {
        loadTask?.cancel()
        isLoading = true
        error = nil
        let board = self.board
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.repository.ranking(board: board)
                if Task.isCancelled { return }
                self.entries = result
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
}
