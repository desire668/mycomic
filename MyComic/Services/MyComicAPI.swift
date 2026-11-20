//
//  MyComicAPI.swift
//  MyComic
//
//  Endpoint construction for mycomic.com. Every URL here is documented and
//  verified in docs/API_ANALYSIS.md.
//

import Foundation

final class MyComicAPI {
    static let shared = MyComicAPI()

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Listing

    func comics(sort: SortOption,
                page: Int,
                filters: [String: String] = [:]) async throws -> ComicListPage {
        let url = try listURL(query: nil, sort: sort, page: page, filters: filters)
        let html = try await client.fetchHTML(url: url)
        let comics = MyComicParser.comics(from: html)
        let maxPage = MyComicParser.maxPage(from: html)
        return ComicListPage(comics: comics, page: page, maxPage: maxPage)
    }

    func search(query: String, sort: SortOption, page: Int) async throws -> ComicListPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ComicListPage(comics: [], page: page, maxPage: 1)
        }
        let url = try listURL(query: trimmed, sort: sort, page: page, filters: [:])
        let html = try await client.fetchHTML(url: url)
        let comics = MyComicParser.comics(from: html)
        let maxPage = MyComicParser.maxPage(from: html)
        return ComicListPage(comics: comics, page: page, maxPage: maxPage)
    }

    func filterGroups() async throws -> [FilterGroup] {
        let url = try listURL(query: nil, sort: .newest, page: 1, filters: [:])
        let html = try await client.fetchHTML(url: url)
        let groups = MyComicParser.filterGroups(from: html)
        return groups.isEmpty ? MyComicParser.fallbackFilterGroups : groups
    }

    // MARK: - Detail / chapters

    func comicDetail(id: String) async throws -> ComicDetail {
        guard let url = URL(string: "\(MyComicSite.chineseBaseURL)/comics/\(id)") else {
            throw AppError.invalidURL
        }
        let html = try await client.fetchHTML(url: url)
        return MyComicParser.detail(from: html, comicId: id)
    }

    func chapterPages(id: String) async throws -> ChapterPages {
        guard let url = URL(string: "\(MyComicSite.chineseBaseURL)/chapters/\(id)") else {
            throw AppError.invalidURL
        }
        let html = try await client.fetchHTML(url: url)
        return MyComicParser.chapterPages(from: html, chapterId: id)
    }

    // MARK: - Ranking

    func ranking(board: RankBoard) async throws -> [RankEntry] {
        guard var components = URLComponents(string: "\(MyComicSite.chineseBaseURL)/rank") else {
            throw AppError.invalidURL
        }
        if let sort = board.queryValue {
            components.queryItems = [URLQueryItem(name: "sort", value: sort)]
        }
        guard let url = components.url else { throw AppError.invalidURL }
        let html = try await client.fetchHTML(url: url)
        return MyComicParser.rank(from: html)
    }

    // MARK: - Home

    func homeFeed(sort: SortOption, page: Int = 1) async throws -> ComicListPage {
        try await comics(sort: sort, page: page)
    }

    // MARK: - Verification

    /// Issues a lightweight request used to check whether the session can
    /// access the site (after a Cloudflare verification).
    func verifyAccess() async throws {
        _ = try await client.fetchHTML(url: URL(string: MyComicSite.chineseBaseURL)!)
    }

    // MARK: - URL building

    private func listURL(query: String?, sort: SortOption, page: Int, filters: [String: String]) throws -> URL {
        guard var components = URLComponents(string: "\(MyComicSite.chineseBaseURL)/comics") else {
            throw AppError.invalidURL
        }
        var items: [URLQueryItem] = []
        if let query = query, !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        if let sortValue = sort.queryValue {
            items.append(URLQueryItem(name: "sort", value: sortValue))
        }
        // Keep a stable order so pagination URLs are reproducible.
        for key in ["tag", "country", "audience", "year", "end"] {
            if let value = filters[key], !value.isEmpty {
                items.append(URLQueryItem(name: "filter[\(key)]", value: value))
            }
        }
        if page > 1 {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        components.queryItems = items.isEmpty ? nil : items
        guard let url = components.url else { throw AppError.invalidURL }
        return url
    }
}
