//
//  DetailViewModel.swift
//  MyComic
//

import Foundation

@MainActor
final class DetailViewModel: ObservableObject {
    @Published private(set) var detail: ComicDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var error: AppError?
    @Published var chaptersAscending = false
    @Published private(set) var isOnShelf = false
    @Published private(set) var lastRecord: ReadingRecord?

    let comicId: String
    let fallbackTitle: String
    let fallbackCover: String

    private let repository: ComicRepository
    private let library: LibraryStore
    private var loadTask: Task<Void, Never>?

    init(comicId: String,
         title: String,
         coverURLString: String,
         repository: ComicRepository = .shared,
         library: LibraryStore = .shared) {
        self.comicId = comicId
        self.fallbackTitle = title
        self.fallbackCover = coverURLString
        self.repository = repository
        self.library = library
        self.isOnShelf = library.isOnShelf(comicId: comicId)
        self.lastRecord = library.record(for: comicId)
    }

    var displayTitle: String { detail?.title ?? fallbackTitle }
    var displayCover: String { detail?.coverURLString ?? fallbackCover }

    /// Chapters in the order requested by the toggle.
    var orderedChapters: [Chapter] {
        guard let chapters = detail?.chapters else { return [] }
        return chaptersAscending ? Array(chapters.reversed()) : chapters
    }

    var canContinue: Bool { lastRecord != nil }

    var chapterCountText: String {
        if let detail = detail {
            return "共 \(detail.chapterCount) 话"
        }
        return ""
    }

    func loadIfNeeded() {
        guard detail == nil, !isLoading else { return }
        reload()
    }

    func reload() {
        loadTask?.cancel()
        isLoading = true
        error = nil
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.repository.detail(comicId: self.comicId, forceRefresh: true)
                if Task.isCancelled { return }
                self.detail = result
                self.error = nil
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

    func refreshShelfState() {
        isOnShelf = library.isOnShelf(comicId: comicId)
        lastRecord = library.record(for: comicId)
    }

    @discardableResult
    func toggleShelf() -> Bool {
        let comic = Comic(
            id: comicId,
            title: displayTitle,
            coverURLString: displayCover,
            latestChapter: detail?.lastChapter?.title
        )
        let added = library.toggleShelf(comic)
        isOnShelf = added
        return added
    }
}
