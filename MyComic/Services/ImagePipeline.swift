//
//  ImagePipeline.swift
//  MyComic
//
//  Image loading with memory cache (NSCache), disk cache, request de-duplication,
//  cancellation and ImageIO downsampling to keep large manga pages out of memory.
//

import Foundation
import UIKit
import CryptoKit
import ImageIO

final class ImagePipeline {
    static let shared = ImagePipeline()

    private let api: APIClient
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.mycomic.image-io", qos: .utility, attributes: .concurrent)
    private let lock = NSLock()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private lazy var cacheDirectory: URL = {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("ComicImages", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private init(api: APIClient = .shared) {
        self.api = api
        memoryCache.countLimit = 320
        memoryCache.totalCostLimit = 160 * 1024 * 1024
    }

    // MARK: - Public API

    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let pixelSize = max(200, Int(maxPixelSize.rounded()))
        let key = "\(url.absoluteString)#\(pixelSize)"
        let cacheKey = key as NSString

        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        if let existing = existingTask(for: key) {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self = self else { return nil }
            defer { self.removeTask(for: key) }

            if Task.isCancelled { return nil }

            if let data = self.diskData(for: url) {
                return await self.decode(data: data, maxPixelSize: pixelSize, key: cacheKey)
            }

            do {
                let data = try await self.api.fetchImageData(url: url)
                if Task.isCancelled { return nil }
                self.writeDiskData(data, for: url)
                return await self.decode(data: data, maxPixelSize: pixelSize, key: cacheKey)
            } catch {
                return nil
            }
        }

        storeTask(task, for: key)
        return await task.value
    }

    /// Downloads images to disk without decoding them, used for neighbour pages.
    func prefetch(_ urls: [URL]) {
        let unique = Array(Set(urls.map { $0.absoluteString }))
        for item in unique {
            guard let url = URL(string: item) else { continue }
            if diskData(for: url) != nil { continue }
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }
                do {
                    let data = try await self.api.fetchImageData(url: url)
                    if !data.isEmpty {
                        self.writeDiskData(data, for: url)
                    }
                } catch {
                    // Prefetch failures are silent by design.
                }
            }
        }
    }

    // MARK: - Disk cache

    static func diskCacheSize() -> Int64 {
        let fileManager = FileManager.default
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("ComicImages", isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for file in files {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
        return total
    }

    func clearCache(completion: (() -> Void)? = nil) {
        memoryCache.removeAllObjects()
        ioQueue.async { [fileManager, cacheDirectory] in
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            DispatchQueue.main.async { completion?() }
        }
    }

    private func diskURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(name).appendingPathExtension("img")
    }

    private func diskData(for url: URL) -> Data? {
        try? Data(contentsOf: diskURL(for: url))
    }

    private func writeDiskData(_ data: Data, for url: URL) {
        let destination = diskURL(for: url)
        if fileManager.fileExists(atPath: destination.path) { return }
        ioQueue.async { [weak self] in
            try? data.write(to: destination, options: .atomic)
            self?.trimDiskCacheIfNeeded()
        }
    }

    /// Keeps the disk cache under ~300 MB by dropping the oldest files.
    private func trimDiskCacheIfNeeded() {
        let limit: Int64 = 300 * 1024 * 1024
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }

        var total: Int64 = 0
        var entries: [(url: URL, size: Int64, date: Date)] = []
        for file in files {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            total += size
            entries.append((file, size, values?.contentModificationDate ?? .distantPast))
        }

        guard total > limit else { return }
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
            if total <= limit { break }
        }
    }

    // MARK: - Decoding

    private func decode(data: Data, maxPixelSize: Int, key: NSString) async -> UIImage? {
        await withCheckedContinuation { continuation in
            ioQueue.async { [weak self] in
                let image = Self.downsample(data: data, maxPixelSize: maxPixelSize)
                if let image = image {
                    let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
                    self?.memoryCache.setObject(image, forKey: key, cost: cost)
                }
                continuation.resume(returning: image)
            }
        }
    }

    static func downsample(data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(data: data)
    }

    // MARK: - Task de-duplication

    private func existingTask(for key: String) -> Task<UIImage?, Never>? {
        lock.lock(); defer { lock.unlock() }
        return inFlight[key]
    }

    private func storeTask(_ task: Task<UIImage?, Never>, for key: String) {
        lock.lock(); defer { lock.unlock() }
        inFlight[key] = task
    }

    private func removeTask(for key: String) {
        lock.lock(); defer { lock.unlock() }
        inFlight[key] = nil
    }
}

// MARK: - SwiftUI loader

@MainActor
final class RemoteImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false

    private var currentURL: URL?
    private var task: Task<Void, Never>?

    func load(url: URL?, maxPixelSize: CGFloat) {
        guard let url = url else {
            cancel()
            image = nil
            return
        }
        if currentURL == url, image != nil { return }

        task?.cancel()
        currentURL = url
        isLoading = true

        task = Task { [weak self] in
            let loaded = await ImagePipeline.shared.image(for: url, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            guard let self = self else { return }
            self.image = loaded
            self.isLoading = false
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }

    deinit {
        task?.cancel()
    }
}
