//
//  ReaderViewModel.swift
//  MyComic
//

import Foundation

struct ReaderRoute: Hashable, Identifiable {
    let comicId: String
    let comicTitle: String
    let coverURLString: String
    let chapterId: String
    let chapterTitle: String

    var id: String { chapterId }
}

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published private(set) var imageURLs: [URL] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: AppError?
    @Published private(set) var comicTitle: String
    @Published private(set) var chapterTitle: String
    @Published private(set) var previousChapterId: String?
    @Published private(set) var nextChapterId: String?
    @Published private(set) var chapters: [Chapter] = []
    @Published var currentIndex: Int = 0
    @Published var showBars = true

    let comicId: String
    let coverURLString: String
    private(set) var chapterId: String
    private(set) var initialPage: Int

    private let repository: ComicRepository
    private let library: LibraryStore
    private let settings: SettingsStore
    private var loadTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    init(route: ReaderRoute,
         repository: ComicRepository = .shared,
         library: LibraryStore = .shared,
         settings: SettingsStore = .shared) {
        self.comicId = route.comicId
        self.coverURLString = route.coverURLString
        self.chapterId = route.chapterId
        self.comicTitle = route.comicTitle
        self.chapterTitle = route.chapterTitle
        self.repository = repository
        self.library = library
        self.settings = settings

        let record = library.record(for: route.comicId)
        if let record = record, record.chapterId == route.chapterId {
            initialPage = record.pageIndex
        } else {
            initialPage = 0
        }
    }

    var pageCount: Int { imageURLs.count }

    var progressText: String {
        guard pageCount > 0 else { return chapterTitle }
        return "\(min(currentIndex + 1, pageCount))/\(pageCount)"
    }

    var hasPreviousChapter: Bool { previousChapterId != nil }
    var hasNextChapter: Bool { nextChapterId != nil }

    // MARK: - Loading

    func load() {
        loadTask?.cancel()
        isLoading = true
        error = nil

        loadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let context = try await self.repository.readerContext(comicId: self.comicId, chapterId: self.chapterId)
                if Task.isCancelled { return }

                self.imageURLs = context.pages.imageURLs
                self.previousChapterId = context.previousChapterId
                self.nextChapterId = context.nextChapterId
                self.chapters = context.chapters
                if !context.comicTitle.isEmpty {
                    self.comicTitle = context.comicTitle
                }
                if let match = context.chapters.first(where: { $0.id == self.chapterId }) {
                    self.chapterTitle = match.title
                }
                self.currentIndex = min(self.initialPage, max(0, self.imageURLs.count - 1))
                self.error = self.imageURLs.isEmpty
                    ? .parse("未能从章节页面解析到图片，可能页面结构已更新。")
                    : nil
                self.isLoading = false
                self.prefetchNeighbors()
                self.saveProgress()
            } catch let appError as AppError {
                if appError.isCancelled { return }
                self.error = appError
                self.isLoading = false
            } catch {
                self.error = .other(error.localizedDescription)
                self.isLoading = false
            }
        }
    }

    func reload() {
        load()
    }

    // MARK: - Chapter switching

    func switchChapter(_ id: String) {
        guard id != chapterId else { return }
        chapterId = id
        initialPage = 0
        imageURLs = []
        currentIndex = 0
        showBars = true
        load()
    }

    func goToPreviousChapter() {
        guard let id = previousChapterId else { return }
        switchChapter(id)
    }

    func goToNextChapter() {
        guard let id = nextChapterId else { return }
        switchChapter(id)
    }

    // MARK: - Progress

    func updateCurrentIndex(_ index: Int) {
        guard index != currentIndex else { return }
        currentIndex = index
        prefetchNeighbors()
        scheduleProgressSave()
    }

    func scheduleProgressSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self = self, !Task.isCancelled else { return }
            self.saveProgress()
        }
    }

    func saveProgress() {
        guard settings.saveReadingHistory, !imageURLs.isEmpty else { return }
        let record = ReadingRecord(
            comicId: comicId,
            comicTitle: comicTitle,
            coverURLString: coverURLString,
            chapterId: chapterId,
            chapterTitle: chapterTitle,
            pageIndex: currentIndex,
            pageCount: imageURLs.count,
            updatedAt: Date()
        )
        library.updateProgress(record)
    }

    // MARK: - Preloading

    func prefetchNeighbors() {
        guard !imageURLs.isEmpty else { return }
        var targets: [URL] = []
        let range = (currentIndex - 2)...(currentIndex + 3)
        for index in range where index >= 0 && index < imageURLs.count && index != currentIndex {
            targets.append(imageURLs[index])
        }
        ImagePipeline.shared.prefetch(targets)
    }
}
