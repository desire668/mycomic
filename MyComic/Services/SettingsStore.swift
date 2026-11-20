//
//  SettingsStore.swift
//  MyComic
//
//  Reading preferences persisted in UserDefaults.
//

import Foundation

enum ReadingMode: String, CaseIterable, Identifiable {
    case vertical
    case paged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical: return "纵向连续"
        case .paged: return "单页翻页"
        }
    }

    var subtitle: String {
        switch self {
        case .vertical: return "上下滚动连续阅读，适合长条漫画"
        case .paged: return "左右滑动逐页阅读"
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    @Published var readingMode: ReadingMode {
        didSet { defaults.set(readingMode.rawValue, forKey: Keys.readingMode) }
    }

    @Published var autoLoadNextChapter: Bool {
        didSet { defaults.set(autoLoadNextChapter, forKey: Keys.autoNextChapter) }
    }

    @Published var keepScreenAwake: Bool {
        didSet { defaults.set(keepScreenAwake, forKey: Keys.keepAwake) }
    }

    @Published var saveReadingHistory: Bool {
        didSet { defaults.set(saveReadingHistory, forKey: Keys.saveHistory) }
    }

    private enum Keys {
        static let readingMode = "mycomic.settings.readingMode"
        static let autoNextChapter = "mycomic.settings.autoNextChapter"
        static let keepAwake = "mycomic.settings.keepAwake"
        static let saveHistory = "mycomic.settings.saveHistory"
    }

    private init() {
        let storedMode = defaults.string(forKey: Keys.readingMode)
        readingMode = ReadingMode(rawValue: storedMode ?? "") ?? .vertical
        autoLoadNextChapter = defaults.object(forKey: Keys.autoNextChapter) as? Bool ?? false
        keepScreenAwake = defaults.object(forKey: Keys.keepAwake) as? Bool ?? false
        saveReadingHistory = defaults.object(forKey: Keys.saveHistory) as? Bool ?? true
    }
}
