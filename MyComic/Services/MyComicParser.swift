//
//  MyComicParser.swift
//  MyComic
//
//  Site specific HTML parsing. All selectors are based on the structures
//  documented in docs/API_ANALYSIS.md and were verified against the live site.
//

import Foundation

enum MyComicParser {

    // MARK: - Comic lists

    /// Parses comic cards from a list / search / home page.
    static func comics(from html: String) -> [Comic] {
        let document = HTMLDocument(html: html)
        var seen = Set<String>()
        var result: [Comic] = []

        let anchors = document.queryAll { node in
            guard node.tag == "a" else { return false }
            guard let href = node.attribute("href") else { return false }
            return href.contains("/cn/comics/")
        }

        for anchor in anchors {
            guard let href = anchor.attribute("href"),
                  let comicId = comicID(fromDetailPath: href) else { continue }
            guard !seen.contains(comicId) else { continue }
            guard let image = anchor.queryFirst({ $0.tag == "img" }) else { continue }

            let cover = (image.attribute("data-src") ?? image.attribute("src") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard cover.contains("biccam.com/comics/") else { continue }

            let alt = (image.attribute("alt") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = alt.isEmpty ? "漫画 \(comicId)" : alt

            let chapterText = anchor.queryAll { $0.hasClass("truncate") }
                .first?
                .textContent
            let latest = (chapterText?.isEmpty == false) ? chapterText : nil

            seen.insert(comicId)
            result.append(Comic(id: comicId, title: title, coverURLString: cover, latestChapter: latest))
        }

        return result
    }

    /// Highest page number advertised by the pagination links.
    static func maxPage(from html: String) -> Int {
        var maxPage = 1
        for match in Regex.matches(pattern: "page=(\\d+)", in: html) {
            if let value = Int(match), value > maxPage {
                maxPage = value
            }
        }
        return maxPage
    }

    // MARK: - Detail

    static func detail(from html: String, comicId: String) -> ComicDetail {
        let document = HTMLDocument(html: html)

        let title = cleanTitle(document.meta("og:title")
            ?? document.root.firstElement(tag: "h1")?.textContent
            ?? "漫画 \(comicId)")

        let cover = document.meta("og:image") ?? "https://biccam.com/comics/\(comicId).jpg"
        let summary = document.meta("description") ?? document.meta("og:description")

        let author = filterLinkTexts(in: document, key: "author").first
        let regions = filterLinkTexts(in: document, key: "country")
        let tags = filterLinkTexts(in: document, key: "tag")
        let endOptions = filterLinkTexts(in: document, key: "end")

        var status = endOptions.first
        if status == nil {
            let text = document.root.textContent
            if text.contains("已完结") { status = "已完结" }
            else if text.contains("连载中") { status = "连载中" }
        }

        let chapters = parseChapters(in: document)
        let pageText = document.root.textContent
        var chapterCount = chapters.count
        if let declared = Regex.firstMatch(pattern: "共\\s*(\\d+)\\s*话", in: pageText).flatMap({ Int($0) }) {
            chapterCount = declared
        }

        return ComicDetail(
            id: comicId,
            title: title,
            coverURLString: cover,
            author: author,
            summary: summary,
            status: status,
            region: regions.first,
            tags: tags,
            chapterCount: chapterCount,
            chapters: chapters
        )
    }

    /// Chapters are taken from the comic's own Alpine `x-data` array, which the
    /// server renders inside the detail page. Scanning every
    /// `a[href*="/cn/chapters/"]` is not safe: the page also contains a
    /// site-wide "最近更新" sidebar with chapters of other comics, so a global
    /// scan made every comic appear to have the same chapters.
    private static func parseChapters(in document: HTMLDocument) -> [Chapter] {
        chaptersFromAlpineData(in: document) ?? chaptersFromChapterGrid(in: document)
    }

    private struct AlpineChapter: Decodable {
        let id: Int
        let title: String
    }

    private static func chaptersFromAlpineData(in document: HTMLDocument) -> [Chapter]? {
        guard let container = document.queryAll({ node in
            (node.attribute("x-data") ?? "").contains("chapters:")
        }).first,
        let data = container.attribute("x-data"),
        let keyRange = data.range(of: "chapters:") else { return nil }

        let characters = Array(data[keyRange.upperBound...])
        guard let start = characters.firstIndex(of: "["),
              let end = matchingBracket(characters, from: start) else { return nil }

        let json = HTMLEntities.decode(String(characters[start...end]))
        guard let payload = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([AlpineChapter].self, from: payload) else { return nil }

        var seen = Set<String>()
        var chapters: [Chapter] = []
        for item in items {
            let id = String(item.id)
            guard !seen.contains(id) else { continue }
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            seen.insert(id)
            chapters.append(Chapter(id: id, title: title))
        }
        return chapters.isEmpty ? nil : chapters
    }

    /// Fallback for pages without the embedded data: only anchors inside the
    /// chapter grid are accepted, which excludes the "最近更新" sidebar.
    private static func chaptersFromChapterGrid(in document: HTMLDocument) -> [Chapter] {
        let anchors = document.queryAll { node in
            guard node.tag == "a", let href = node.attribute("href") else { return false }
            return href.contains("/cn/chapters/") && isInsideChapterGrid(node)
        }

        var seen = Set<String>()
        var chapters: [Chapter] = []

        for anchor in anchors {
            guard let href = anchor.attribute("href"),
                  let chapterId = Regex.firstMatch(pattern: "/cn/chapters/(\\d+)", in: href) else { continue }
            guard !seen.contains(chapterId) else { continue }

            let text = anchor.textContent
            guard !text.isEmpty else { continue }
            if ["开始阅读", "上一话", "下一话", "上一章", "下一章", "返回目录"].contains(where: { text.contains($0) }) {
                continue
            }

            seen.insert(chapterId)
            chapters.append(Chapter(id: chapterId, title: text))
        }

        return chapters
    }

    private static func isInsideChapterGrid(_ node: HTMLNode) -> Bool {
        var ancestor = node.parent
        var depth = 0
        while let current = ancestor, depth < 8 {
            if current.tag == "template" { return false }
            if current.classNames.contains(where: { $0.hasPrefix("grid-cols") }) { return true }
            ancestor = current.parent
            depth += 1
        }
        return false
    }

    /// Returns the index of the `]` matching the `[` at `start`, ignoring
    /// brackets that appear inside JSON string literals.
    private static func matchingBracket(_ characters: [Character], from start: Int) -> Int? {
        var depth = 0
        var inString = false
        var index = start

        while index < characters.count {
            let character = characters[index]
            if inString {
                if character == "\\" {
                    index += 1
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"":
                    inString = true
                case "[":
                    depth += 1
                case "]":
                    depth -= 1
                    if depth == 0 { return index }
                default:
                    break
                }
            }
            index += 1
        }
        return nil
    }

    // MARK: - Chapter images

    static func chapterPages(from html: String, chapterId: String) -> ChapterPages {
        let document = HTMLDocument(html: html)

        var seen = Set<String>()
        var collected: [(page: Int?, order: Int, url: URL)] = []

        let images = document.queryAll { $0.tag == "img" }
        for image in images {
            let source = (image.attribute("data-src") ?? image.attribute("src") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard source.contains("biccam.com/chapters/") else { continue }
            guard let url = absoluteURL(source) else { continue }
            let key = url.absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let page = Regex.firstMatch(pattern: "^(\\d+)-[0-9a-zA-Z]+\\.[a-zA-Z]+$", in: url.lastPathComponent)
                .flatMap { Int($0) }
            collected.append((page, collected.count, url))
        }

        // Prefer the numeric page order encoded in the file name.
        if collected.allSatisfy({ $0.page != nil }) {
            collected.sort { ($0.page ?? 0) < ($1.page ?? 0) }
        }

        var previousChapterId: String?
        var nextChapterId: String?
        var comicId: String?

        for anchor in document.queryAll({ $0.tag == "a" }) {
            guard let href = anchor.attribute("href") else { continue }
            let text = anchor.textContent
            if text.contains("上一话") || text.contains("上一章") {
                previousChapterId = Regex.firstMatch(pattern: "/cn/chapters/(\\d+)", in: href)
            } else if text.contains("下一话") || text.contains("下一章") {
                nextChapterId = Regex.firstMatch(pattern: "/cn/chapters/(\\d+)", in: href)
            } else if text.contains("返回目录") || text.contains("目录") {
                comicId = Regex.firstMatch(pattern: "/cn/comics/(\\d+)", in: href)
            }
        }

        let comicTitle = cleanTitle(document.meta("og:title") ?? "")

        return ChapterPages(
            chapterId: chapterId,
            comicId: comicId,
            comicTitle: comicTitle,
            chapterTitle: nil,
            imageURLs: collected.map { $0.url },
            previousChapterId: previousChapterId,
            nextChapterId: nextChapterId
        )
    }

    // MARK: - Ranking

    static func rank(from html: String) -> [RankEntry] {
        let document = HTMLDocument(html: html)
        var entries: [RankEntry] = []

        for row in document.queryAll({ $0.tag == "tr" }) {
            let anchors = row.queryAll { $0.tag == "a" }
            guard let main = anchors.first(where: {
                guard let href = $0.attribute("href") else { return false }
                return detailComicID(fromDetailPath: href) != nil
            }), let href = main.attribute("href"),
               let comicId = detailComicID(fromDetailPath: href) else { continue }

            let title = main.textContent
            guard !title.isEmpty else { continue }

            let author = anchors.first(where: {
                ($0.attribute("href") ?? "").removingPercentEncoding?.contains("filter[author]=") == true
            })?.textContent

            let chapter = anchors.first(where: {
                ($0.attribute("href") ?? "").contains("/cn/chapters/")
            })?.textContent

            let rowText = row.textContent
            let updated = Regex.firstFullMatch(pattern: "\\d{4}-\\d{2}-\\d{2}", in: rowText)
            let score = row.queryAll { $0.tag == "td" }
                .compactMap { cell -> String? in
                    let value = cell.textContent
                    return Regex.firstFullMatch(pattern: "^\\d+(\\.\\d+)?$", in: value)
                }
                .last

            let rankNumber = entries.count + 1
            entries.append(RankEntry(
                rank: rankNumber,
                comicId: comicId,
                title: title,
                author: author?.isEmpty == false ? author : nil,
                latestChapter: chapter?.isEmpty == false ? chapter : nil,
                updatedAt: updated,
                score: score
            ))
        }

        return entries
    }

    // MARK: - Filter options

    static func filterGroups(from html: String) -> [FilterGroup] {
        let document = HTMLDocument(html: html)
        let titles: [(key: String, title: String)] = [
            ("tag", "作品类型"),
            ("country", "作品地区"),
            ("audience", "适合受众"),
            ("year", "出品年份"),
            ("end", "目前进度")
        ]

        var buckets: [String: [FilterOption]] = [:]
        var order: [String: [String]] = [:]

        for anchor in document.queryAll({ $0.tag == "a" }) {
            guard let rawHref = anchor.attribute("href") else { continue }
            let href = rawHref.removingPercentEncoding ?? rawHref
            guard href.contains("filter["),
                  let groups = Regex.captureGroups(
                    pattern: "filter\\[(tag|country|audience|year|end)\\]=(.+?)(?:&|$)",
                    in: href
                  ),
                  groups.count == 3 else { continue }

            let key = groups[1]
            let value = groups[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let label = anchor.textContent
            guard !label.isEmpty else { continue }

            if order[key]?.contains(value) != true {
                order[key, default: []].append(value)
                buckets[key, default: []].append(FilterOption(label: label, value: value))
            }
        }

        var result: [FilterGroup] = []
        for title in titles {
            if let options = buckets[title.key], !options.isEmpty {
                result.append(FilterGroup(key: title.key, title: title.title, options: options))
            }
        }
        return result
    }

    /// Minimal, verified fallback used when the sidebar fails to parse.
    static var fallbackFilterGroups: [FilterGroup] {
        [
            FilterGroup(key: "tag", title: "作品类型", options: [
                FilterOption(label: "魔幻", value: "mohuan"),
                FilterOption(label: "魔法", value: "mofa")
            ]),
            FilterGroup(key: "country", title: "作品地区", options: [
                FilterOption(label: "日本", value: "japan"),
                FilterOption(label: "港台", value: "hongkong")
            ]),
            FilterGroup(key: "audience", title: "适合受众", options: [
                FilterOption(label: "少女", value: "shaonv"),
                FilterOption(label: "少年", value: "shaonian"),
                FilterOption(label: "青年", value: "qingnian")
            ]),
            FilterGroup(key: "end", title: "目前进度", options: [
                FilterOption(label: "连载中", value: "0"),
                FilterOption(label: "已完结", value: "1")
            ])
        ]
    }

    // MARK: - Helpers

    private static func filterLinkTexts(in document: HTMLDocument, key: String) -> [String] {
        var texts: [String] = []
        var seen = Set<String>()
        for anchor in document.queryAll({ $0.tag == "a" }) {
            guard let rawHref = anchor.attribute("href") else { continue }
            let href = rawHref.removingPercentEncoding ?? rawHref
            guard href.contains("filter[\(key)]=") else { continue }
            let text = anchor.textContent
            guard !text.isEmpty, !seen.contains(text) else { continue }
            seen.insert(text)
            texts.append(text)
        }
        return texts
    }

    private static func comicID(fromDetailPath href: String) -> String? {
        Regex.firstMatch(pattern: "/cn/comics/(\\d+)(?![\\d])", in: href)
    }

    private static func detailComicID(fromDetailPath href: String) -> String? {
        // Ranking links are exactly /cn/comics/{id}; author filters contain a query string.
        guard let components = URLComponents(string: href),
              components.query == nil else { return nil }
        return Regex.firstMatch(pattern: "/cn/comics/(\\d+)/?$", in: components.path)
    }

    private static func absoluteURL(_ string: String) -> URL? {
        if string.hasPrefix("http") { return URL(string: string) }
        if string.hasPrefix("//") { return URL(string: "https:" + string) }
        return nil
    }

    private static func cleanTitle(_ title: String) -> String {
        var value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" - MYCOMIC - 我的漫画", " - MYCOMIC", " | MYCOMIC", "MYCOMIC - 我的漫画"] {
            if value.hasSuffix(suffix) {
                value = String(value.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return value.isEmpty ? "MyComic" : value
    }
}

// MARK: - Regex helpers

enum Regex {
    static func firstMatch(pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range),
              match.numberOfRanges > 1,
              let groupRange = Range(match.range(at: 1), in: string) else { return nil }
        return String(string[groupRange])
    }

    /// Returns the whole match, for patterns without capture groups.
    static func firstFullMatch(pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range),
              let matchRange = Range(match.range, in: string) else { return nil }
        return String(string[matchRange])
    }

    static func matches(pattern: String, in string: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.matches(in: string, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1, let groupRange = Range(match.range(at: 1), in: string) else { return nil }
            return String(string[groupRange])
        }
    }

    /// Returns capture groups with index 0 == full match.
    static func captureGroups(pattern: String, in string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard let groupRange = Range(match.range(at: index), in: string) else { return "" }
            return String(string[groupRange])
        }
    }
}
