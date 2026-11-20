//
//  LibraryStore.swift
//  MyComic
//
//  Local-only shelf and reading history. The site has no public bookmark API,
//  so this data never leaves the device. The UI clearly labels it as local.
//

import Foundation

final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var shelf: [Comic] = []
    @Published private(set) var history: [ReadingRecord] = []

    private let fileManager = FileManager.default
    private let saveQueue = DispatchQueue(label: "com.mycomic.library.save", qos: .utility)

    private struct Payload: Codable {
        var shelf: [Comic]
        var history: [ReadingRecord]
    }

    private lazy var fileURL: URL = {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("mycomic-library.json")
    }()

    private init() {
        load()
    }

    // MARK: - Shelf

    func isOnShelf(comicId: String) -> Bool {
        shelf.contains { $0.id == comicId }
    }

    func addToShelf(_ comic: Comic) {
        guard !isOnShelf(comicId: comic.id) else { return }
        shelf.insert(comic, at: 0)
        save()
    }

    func removeFromShelf(comicId: String) {
        shelf.removeAll { $0.id == comicId }
        save()
    }

    @discardableResult
    func toggleShelf(_ comic: Comic) -> Bool {
        if isOnShelf(comicId: comic.id) {
            removeFromShelf(comicId: comic.id)
            return false
        } else {
            addToShelf(comic)
            return true
        }
    }

    // MARK: - History

    func record(for comicId: String) -> ReadingRecord? {
        history.first { $0.comicId == comicId }
    }

    func updateProgress(_ record: ReadingRecord) {
        history.removeAll { $0.comicId == record.comicId }
        history.insert(record, at: 0)
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        save()
    }

    func removeHistory(comicId: String) {
        history.removeAll { $0.comicId == comicId }
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    var continueReading: ReadingRecord? {
        history.first
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        shelf = payload.shelf
        history = payload.history
    }

    private func save() {
        let payload = Payload(shelf: shelf, history: history)
        saveQueue.async { [fileURL] in
            guard let data = try? JSONEncoder().encode(payload) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
