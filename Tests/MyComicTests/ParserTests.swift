//
//  ParserTests.swift
//  MyComicTests
//
//  Fixtures mirror the structures documented in docs/API_ANALYSIS.md; they were
//  captured from the live site and stripped of unrelated markup.
//

import XCTest
@testable import MyComic

final class ParserTests: XCTestCase {

    // MARK: - Comic lists

    private let listHTML = """
    <!DOCTYPE html>
    <html><body>
    <div class="grid grid-cols-3">
      <div class="group relative">
        <a href="https://mycomic.com/cn/comics/1234">
          <img src="https://biccam.com/comics/1234-abc123.jpg" alt="测试漫画" loading="lazy">
          <div class="text-white text-sm pb-3 truncate">第 10 话</div>
        </a>
        <div class="text-sm text-white truncate">测试漫画</div>
      </div>
      <div class="group relative">
        <a href="/cn/comics/5678">
          <img data-src="https://biccam.com/comics/5678-def456.jpg" alt="第二部">
          <div class="truncate">第 2 话</div>
        </a>
      </div>
    </div>
    <nav>
      <a href="/cn/comics?page=2">2</a>
      <a href="/cn/comics?page=6">6</a>
      <a href="/cn/comics?filter[tag]=mohuan">魔幻</a>
    </nav>
    </body></html>
    """

    func testComicListParsing() {
        let comics = MyComicParser.comics(from: listHTML)
        XCTAssertEqual(comics.count, 2)

        XCTAssertEqual(comics[0].id, "1234")
        XCTAssertEqual(comics[0].title, "测试漫画")
        XCTAssertEqual(comics[0].coverURLString, "https://biccam.com/comics/1234-abc123.jpg")
        XCTAssertEqual(comics[0].latestChapter, "第 10 话")

        XCTAssertEqual(comics[1].id, "5678")
        XCTAssertEqual(comics[1].coverURLString, "https://biccam.com/comics/5678-def456.jpg")
    }

    func testEmptyListReturnsNoComics() {
        XCTAssertTrue(MyComicParser.comics(from: "<html><body>没有结果</body></html>").isEmpty)
    }

    func testMaxPageParsing() {
        XCTAssertEqual(MyComicParser.maxPage(from: listHTML), 6)
        XCTAssertEqual(MyComicParser.maxPage(from: "<html>no links</html>"), 1)
    }

    // MARK: - Detail

    private let detailHTML = """
    <html><head>
    <meta property="og:title" content="测试漫画 - MYCOMIC - 我的漫画">
    <meta property="og:image" content="https://biccam.com/comics/1234-abc123.jpg">
    <meta name="description" content="这是简介。">
    </head><body>
    <a href="/cn/comics?filter[author]=%E4%BD%9C%E8%80%85A">作者A</a>
    <a href="/cn/comics?filter[country]=japan">日本</a>
    <a href="/cn/comics?filter[tag]=mohuan">魔幻</a>
    <a href="/cn/comics?filter[tag]=rexue">热血</a>
    <a href="/cn/comics?filter[end]=0">连载中</a>
    <p>共 603 话</p>
    <div x-data="{ chapters: [{&quot;id&quot;:9001,&quot;title&quot;:&quot;第 603 话&quot;},{&quot;id&quot;:9002,&quot;title&quot;:&quot;第 602 话&quot;},{&quot;id&quot;:9,&quot;title&quot;:&quot;第 1 话（序）&quot;}] }">
      <div class="grid grid-cols-3 gap-2">
        <template x-for="chapter in chapters"><a href="https://mycomic.com/cn/comics/1">第 1 话</a></template>
      </div>
    </div>
    <a href="/cn/chapters/9001">开始阅读</a>
    <section>
      <h3>最近更新</h3>
      <div><a href="/cn/comics/5555">别的漫画</a><a href="/cn/chapters/7777">第 9 话</a></div>
    </section>
    </body></html>
    """

    func testDetailParsing() {
        let detail = MyComicParser.detail(from: detailHTML, comicId: "1234")

        XCTAssertEqual(detail.title, "测试漫画")
        XCTAssertEqual(detail.coverURLString, "https://biccam.com/comics/1234-abc123.jpg")
        XCTAssertEqual(detail.summary, "这是简介。")
        XCTAssertEqual(detail.author, "作者A")
        XCTAssertEqual(detail.region, "日本")
        XCTAssertEqual(detail.status, "连载中")
        XCTAssertEqual(detail.tags, ["魔幻", "热血"])
        XCTAssertEqual(detail.chapterCount, 603)
        XCTAssertEqual(detail.chapters.map { $0.id }, ["9001", "9002", "9"])
        XCTAssertFalse(detail.chapters.contains { $0.id == "7777" })
        XCTAssertFalse(detail.chapters.contains { $0.title == "开始阅读" })
    }

    // MARK: - Chapter ownership (regression)

    func testDetailChaptersFallbackToChapterGrid() {
        let html = """
        <html><body>
        <div class="grid grid-cols-3 gap-2">
          <a href="/cn/chapters/501">第 2 话</a>
          <a href="/cn/chapters/502">第 1 话</a>
        </div>
        <section>
          <h3>最近更新</h3>
          <div><a href="/cn/comics/5555">别的漫画</a><a href="/cn/chapters/7777">第 9 话</a></div>
        </section>
        </body></html>
        """

        let detail = MyComicParser.detail(from: html, comicId: "1234")
        XCTAssertEqual(detail.chapters.map { $0.id }, ["501", "502"])
        XCTAssertEqual(detail.chapters.map { $0.title }, ["第 2 话", "第 1 话"])
    }

    func testDetailNeverUsesSidebarChapters() {
        let html = """
        <html><body>
        <a href="/cn/chapters/9001">开始阅读</a>
        <section>
          <h3>最近更新</h3>
          <div><a href="/cn/comics/5555">别的漫画</a><a href="/cn/chapters/7777">第 9 话</a></div>
        </section>
        </body></html>
        """

        let detail = MyComicParser.detail(from: html, comicId: "1234")
        XCTAssertTrue(detail.chapters.isEmpty)
        XCTAssertFalse(detail.chapters.contains { $0.id == "7777" })
    }

    // MARK: - Chapter images

    private let chapterHTML = """
    <html><head>
    <meta property="og:title" content="第 1 话 - 测试漫画 - MYCOMIC">
    </head><body>
    <img src="https://biccam.com/chapters/9001/2-bbb.jpg">
    <img data-src="https://biccam.com/chapters/9001/1-aaa.jpg">
    <img src="https://mycomic.com/logo.png">
    <a href="/cn/chapters/9000">上一话</a>
    <a href="/cn/chapters/9002">下一话</a>
    <a href="/cn/comics/1234">返回目录</a>
    </body></html>
    """

    func testChapterPagesParsing() {
        let pages = MyComicParser.chapterPages(from: chapterHTML, chapterId: "9001")

        XCTAssertEqual(pages.imageURLs.map { $0.lastPathComponent }, ["1-aaa.jpg", "2-bbb.jpg"])
        XCTAssertEqual(pages.previousChapterId, "9000")
        XCTAssertEqual(pages.nextChapterId, "9002")
        XCTAssertEqual(pages.comicId, "1234")
        XCTAssertEqual(pages.comicTitle, "第 1 话 - 测试漫画")
    }

    func testChapterWithoutImages() {
        let pages = MyComicParser.chapterPages(from: "<html><body></body></html>", chapterId: "1")
        XCTAssertTrue(pages.imageURLs.isEmpty)
        XCTAssertNil(pages.previousChapterId)
    }

    // MARK: - Ranking

    private let rankHTML = """
    <html><body><table><tbody>
    <tr data-flux-row>
      <td data-flux-cell>1</td>
      <td data-flux-cell>
        <a href="/cn/comics/1234">测试漫画</a>
        <a href="/cn/comics?filter[author]=%E4%BD%9C%E8%80%85A">作者A</a>
      </td>
      <td data-flux-cell><a href="/cn/chapters/9001">第 603 话</a></td>
      <td data-flux-cell>2026-01-02</td>
      <td data-flux-cell>9.6</td>
    </tr>
    <tr data-flux-row>
      <td data-flux-cell>2</td>
      <td data-flux-cell><a href="/cn/comics/5678">第二部</a></td>
      <td data-flux-cell><a href="/cn/chapters/8001">第 2 话</a></td>
      <td data-flux-cell>2026-01-01</td>
      <td data-flux-cell>9.2</td>
    </tr>
    </tbody></table></body></html>
    """

    func testRankingParsing() {
        let entries = MyComicParser.rank(from: rankHTML)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].rank, 1)
        XCTAssertEqual(entries[0].comicId, "1234")
        XCTAssertEqual(entries[0].title, "测试漫画")
        XCTAssertEqual(entries[0].author, "作者A")
        XCTAssertEqual(entries[0].latestChapter, "第 603 话")
        XCTAssertEqual(entries[0].updatedAt, "2026-01-02")
        XCTAssertEqual(entries[0].score, "9.6")
    }

    // MARK: - Filter groups

    func testFilterGroupsParsing() {
        let html = """
        <html><body>
        <a href="/cn/comics?filter[tag]=mohuan">魔幻</a>
        <a href="/cn/comics?filter[tag]=mofa">魔法</a>
        <a href="/cn/comics?filter[country]=japan&sort=-update">日本</a>
        <a href="/cn/comics?filter[end]=0">连载中</a>
        </body></html>
        """

        let groups = MyComicParser.filterGroups(from: html)
        let keys = groups.map { $0.key }
        XCTAssertEqual(keys, ["tag", "country", "end"])

        let tagGroup = groups.first { $0.key == "tag" }
        XCTAssertEqual(tagGroup?.options.map { $0.value }, ["mohuan", "mofa"])
        XCTAssertEqual(tagGroup?.options.first?.label, "魔幻")

        let countryGroup = groups.first { $0.key == "country" }
        XCTAssertEqual(countryGroup?.options.first?.value, "japan")
    }

    // MARK: - Entities

    func testHTMLEntityDecoding() {
        let document = HTMLDocument(html: "<div>A &amp; B &#20320;&#22909; &mdash; C</div>")
        XCTAssertEqual(document.root.textContent, "A & B 你好 — C")
    }
}
