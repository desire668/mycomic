//
//  Comic.swift
//  MyComic
//
//  Core data models shared by the network layer, repositories and views.
//

import Foundation

// MARK: - Comic list item

struct Comic: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var coverURLString: String
    var latestChapter: String?

    var coverURL: URL? { URL(string: coverURLString) }
    var detailURL: URL? { URL(string: "https://mycomic.com/cn/comics/\(id)") }

    init(id: String, title: String, coverURLString: String, latestChapter: String? = nil) {
        self.id = id
        self.title = title
        self.coverURLString = coverURLString
        self.latestChapter = latestChapter
    }
}

// MARK: - Paginated list

struct ComicListPage {
    var comics: [Comic]
    var page: Int
    var maxPage: Int

    var hasMore: Bool { page < maxPage }
}

// MARK: - Chapter

struct Chapter: Identifiable, Hashable {
    let id: String
    let title: String
}

// MARK: - Comic detail

struct ComicDetail {
    let id: String
    var title: String
    var coverURLString: String
    var author: String?
    var summary: String?
    var status: String?
    var region: String?
    var tags: [String]
    var chapterCount: Int
    var chapters: [Chapter]

    var coverURL: URL? { URL(string: coverURLString) }
    var firstChapter: Chapter? { chapters.first }
    var lastChapter: Chapter? { chapters.last }
}

// MARK: - Chapter reading pages

struct ChapterPages {
    let chapterId: String
    var comicId: String?
    var comicTitle: String
    var chapterTitle: String?
    var imageURLs: [URL]
    var previousChapterId: String?
    var nextChapterId: String?
}

// MARK: - Ranking

struct RankEntry: Identifiable, Hashable {
    var rank: Int
    let comicId: String
    var title: String
    var author: String?
    var latestChapter: String?
    var updatedAt: String?
    var score: String?

    var id: String { comicId }
}

// MARK: - Filters

struct FilterOption: Identifiable, Hashable {
    let label: String
    let value: String
    var id: String { value }
}

struct FilterGroup: Identifiable, Hashable {
    let key: String
    let title: String
    var options: [FilterOption]
    var id: String { key }
}

// MARK: - Sorting

enum SortOption: String, CaseIterable, Identifiable {
    case newest
    case updated
    case popular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "最新上架"
        case .updated: return "最近更新"
        case .popular: return "最高人气"
        }
    }

    /// `nil` means the site's default order (newest first).
    var queryValue: String? {
        switch self {
        case .newest: return nil
        case .updated: return "-update"
        case .popular: return "-views"
        }
    }
}

// MARK: - Ranking board

enum RankBoard: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "日排行"
        case .weekly: return "週排行"
        case .monthly: return "月排行"
        case .allTime: return "历史排行"
        }
    }

    var queryValue: String? {
        switch self {
        case .daily: return nil
        case .weekly: return "-week"
        case .monthly: return "-month"
        case .allTime: return "-views"
        }
    }
}

// MARK: - Local shelf / reading history

struct ReadingRecord: Codable, Hashable, Identifiable {
    let comicId: String
    var comicTitle: String
    var coverURLString: String
    var chapterId: String
    var chapterTitle: String
    var pageIndex: Int
    var pageCount: Int
    var updatedAt: Date

    var id: String { comicId }
    var coverURL: URL? { URL(string: coverURLString) }

    var progressText: String {
        guard pageCount > 0 else { return chapterTitle }
        return "\(chapterTitle) · \(pageIndex + 1)/\(pageCount)"
    }
}
