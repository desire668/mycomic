//
//  ComicRepository.swift
//  MyComic
//
//  Single entry point for screens: hides the API details, adds a short lived
//  detail cache and keeps pagination logic in one place.
//

import Foundation

struct HomeFeed {
    var recentUpdates: [Comic]
    var latest: [Comic]
    var popular: [Comic]
}

final class ComicRepository {
    static let shared = ComicRepository()

    private let api: MyComicAPI
    private let lock = NSLock()
    private var detailCache: [String: (detail: ComicDetail, date: Date)] = [:]
    private var filterCache: (groups: [FilterGroup], date: Date)?
    private let detailTTL: TimeInterval = 300

    init(api: MyComicAPI = .shared) {
        self.api = api
    }

    // MARK: - Home

    func homeFeed() async throws -> HomeFeed {
        async let recent = api.comics(sort: .updated, page: 1)
        async let latest = api.comics(sort: .newest, page: 1)
        async let popular = api.comics(sort: .popular, page: 1)

        let (recentPage, latestPage, popularPage) = try await (recent, latest, popular)
        return HomeFeed(
            recentUpdates: recentPage.comics,
            latest: latestPage.comics,
            popular: popularPage.comics
        )
    }

    // MARK: - Lists

    func list(sort: SortOption, page: Int, filters: [String: String]) async throws -> ComicListPage {
        try await api.comics(sort: sort, page: page, filters: filters)
    }

    func search(query: String, sort: SortOption, page: Int) async throws -> ComicListPage {
        try await api.search(query: query, sort: sort, page: page)
    }

    func ranking(board: RankBoard) async throws -> [RankEntry] {
        try await api.ranking(board: board)
    }

    func filterGroups(forceRefresh: Bool = false) async throws -> [FilterGroup] {
        lock.lock()
        let cached = filterCache
        lock.unlock()

        if !forceRefresh, let cached = cached, Date().timeIntervalSince(cached.date) < 3600 {
            return cached.groups
        }

        let groups = try await api.filterGroups()
        lock.lock()
        filterCache = (groups, Date())
        lock.unlock()
        return groups
    }

    // MARK: - Detail

    func detail(comicId: String, forceRefresh: Bool = false) async throws -> ComicDetail {
        lock.lock()
        let cached = detailCache[comicId]
        lock.unlock()

        if !forceRefresh, let cached = cached, Date().timeIntervalSince(cached.date) < detailTTL {
            return cached.detail
        }

        let detail = try await api.comicDetail(id: comicId)
        lock.lock()
        detailCache[comicId] = (detail, Date())
        lock.unlock()
        return detail
    }

    func chapterPages(chapterId: String) async throws -> ChapterPages {
        try await api.chapterPages(id: chapterId)
    }

    /// Loads a chapter and resolves the neighbouring chapter ids from the
    /// detail page when the reader page itself does not expose them.
    func readerContext(comicId: String?, chapterId: String) async throws -> ReaderContext {
        let pages = try await api.chapterPages(id: chapterId)
        var chapters: [Chapter] = []
        var comicTitle = pages.comicTitle

        if let comicId = comicId {
            if let detail = try? await detail(comicId: comicId) {
                chapters = detail.chapters
                if !detail.title.isEmpty { comicTitle = detail.title }
            }
        }

        var previous = pages.previousChapterId
        var next = pages.nextChapterId

        if let index = chapters.firstIndex(where: { $0.id == chapterId }) {
            // `chapters` is in descending order (newest first), so the older
            // chapter comes after and the newer one before.
            if index + 1 < chapters.count, previous == nil {
                previous = chapters[index + 1].id
            }
            if index - 1 >= 0, next == nil {
                next = chapters[index - 1].id
            }
        }

        return ReaderContext(pages: pages, comicTitle: comicTitle, chapters: chapters, previousChapterId: previous, nextChapterId: next)
    }
}

struct ReaderContext {
    var pages: ChapterPages
    var comicTitle: String
    var chapters: [Chapter]
    var previousChapterId: String?
    var nextChapterId: String?
}
