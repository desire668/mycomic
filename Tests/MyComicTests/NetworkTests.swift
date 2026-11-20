//
//  NetworkTests.swift
//  MyComicTests
//
//  Exercises APIClient / MyComicAPI through a stubbed URLProtocol so HTTP,
//  Cloudflare and transport failures can be verified without the live site.
//

import XCTest
import UIKit
@testable import MyComic

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lastRequest = request
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class NetworkTests: XCTestCase {
    private var client: APIClient!
    private var api: MyComicAPI!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        // Isolate cookies from the real shared store so tests never leak state.
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)

        client = APIClient(session: session)
        api = MyComicAPI(client: client)
        MockURLProtocol.handler = nil
        MockURLProtocol.lastRequest = nil
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        MockURLProtocol.lastRequest = nil
        client = nil
        api = nil
        super.tearDown()
    }

    private func respond(status: Int, body: String, headers: [String: String] = [:]) {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: status,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: headers)!
            return (response, Data(body.utf8))
        }
    }

    private let listHTML = """
    <html><body>
    <a href="/cn/comics/1234"><img src="https://biccam.com/comics/1234-a.jpg" alt="测试漫画"><div class="truncate">第 1 话</div></a>
    <a href="/cn/comics?page=3">3</a>
    </body></html>
    """

    // MARK: - URL construction

    func testListRequestEncodesSortFiltersAndPage() async throws {
        respond(status: 200, body: listHTML)

        let page = try await api.comics(sort: .popular, page: 2, filters: ["tag": "mohuan", "country": "japan"])
        XCTAssertEqual(page.comics.count, 1)
        XCTAssertEqual(page.page, 2)
        XCTAssertEqual(page.maxPage, 3)

        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.path, "/cn/comics")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "sort", value: "-views")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "filter[tag]", value: "mohuan")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "filter[country]", value: "japan")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "page", value: "2")))
    }

    func testFirstPageOmitsPageParameter() async throws {
        respond(status: 200, body: listHTML)

        _ = try await api.comics(sort: .newest, page: 1)
        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertFalse(items.contains { $0.name == "page" })
        XCTAssertFalse(items.contains { $0.name == "sort" })
    }

    func testSearchUsesQueryParameter() async throws {
        respond(status: 200, body: listHTML)

        _ = try await api.search(query: "one piece", sort: .updated, page: 1)
        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(items.contains(URLQueryItem(name: "q", value: "one piece")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "sort", value: "-update")))
    }

    func testEmptySearchSkipsNetwork() async throws {
        MockURLProtocol.handler = { _ in
            XCTFail("Empty queries must not hit the network")
            throw URLError(.badURL)
        }
        let page = try await api.search(query: "   ", sort: .newest, page: 1)
        XCTAssertTrue(page.comics.isEmpty)
    }

    func testDetailAndChapterURLs() async throws {
        respond(status: 200, body: "<html><body></body></html>")
        _ = try await api.comicDetail(id: "1234")
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/cn/comics/1234")

        _ = try await api.chapterPages(id: "9001")
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.path, "/cn/chapters/9001")
    }

    func testRankingURL() async throws {
        respond(status: 200, body: "<html><body></body></html>")
        _ = try await api.ranking(board: .monthly)
        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.path, "/cn/rank")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "-month")
    }

    // MARK: - HTTP failures

    func testHTTP404IsMapped() async {
        respond(status: 404, body: "not found")
        do {
            _ = try await api.comicDetail(id: "0")
            XCTFail("Expected an error")
        } catch let error as AppError {
            XCTAssertEqual(error, .http(404))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHTTP503WithoutChallengeIsMapped() async {
        respond(status: 503, body: "Service Unavailable")
        do {
            _ = try await api.comics(sort: .newest, page: 1)
            XCTFail("Expected an error")
        } catch let error as AppError {
            XCTAssertEqual(error, .http(503))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCloudflareChallengeOn403() async {
        respond(status: 403, body: "<html><title>Just a moment...</title><div id=\"challenge-platform\"></div></html>")
        do {
            _ = try await api.comics(sort: .newest, page: 1)
            XCTFail("Expected a Cloudflare error")
        } catch let error as AppError {
            XCTAssertEqual(error, .cloudflareRequired(403))
            XCTAssertTrue(error.isCloudflare)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCloudflareChallengeHeader() {
        let headers: [AnyHashable: Any] = ["cf-mitigated": "challenge"]
        XCTAssertTrue(CloudflareDetector.isChallenge(status: 200, headers: headers, body: ""))
        XCTAssertFalse(CloudflareDetector.isChallenge(status: 200, headers: [:], body: "ok"))
    }

    // MARK: - Transport failures

    func testTimeoutIsMapped() async {
        MockURLProtocol.handler = { _ in throw URLError(.timedOut) }
        do {
            _ = try await api.comics(sort: .newest, page: 1)
            XCTFail("Expected a timeout")
        } catch let error as AppError {
            XCTAssertEqual(error, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOfflineIsMapped() async {
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await api.comics(sort: .newest, page: 1)
            XCTFail("Expected an offline error")
        } catch let error as AppError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Images

    func testImageRequestSendsReferer() async throws {
        let payload = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/jpeg"])!
            return (response, payload)
        }

        let url = URL(string: "https://biccam.com/chapters/9001/1-aaa.jpg")!
        let data = try await client.fetchImageData(url: url)
        XCTAssertEqual(data, payload)
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Referer"), "https://mycomic.com/")
    }

    func testImage403IsReportedAsFriendlyError() async {
        respond(status: 403, body: "")
        do {
            _ = try await client.fetchImageData(url: URL(string: "https://biccam.com/x.jpg")!)
            XCTFail("Expected an error")
        } catch let error as AppError {
            guard case .other(let message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(message.contains("403"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - downsampling

    func testDownsampleRejectsInvalidData() {
        XCTAssertNil(ImagePipeline.downsample(data: Data([0x00, 0x01]), maxPixelSize: 100))
    }

    func testDownsampleKeepsSmallImage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let data = try XCTUnwrap(image.pngData())
        let downsampled = ImagePipeline.downsample(data: data, maxPixelSize: 64)
        XCTAssertNotNil(downsampled)
        XCTAssertLessThanOrEqual(max(downsampled!.size.width, downsampled!.size.height), 64)
    }
}
