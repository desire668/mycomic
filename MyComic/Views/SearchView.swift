//
//  SearchView.swift
//  MyComic
//
//  Native search entry point. The query is executed by the website itself
//  (GET /cn/comics?q=…), so results always match the site exactly.
//

import SwiftUI

final class SearchTabModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var webModel: WebViewModel?
    @Published private(set) var recentSearches: [String] = []

    private let recentKey = "com.mycomic.recentSearches"
    private let maxRecentCount = 10

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    func submit() {
        search(query)
    }

    func search(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = Site.searchURL(for: trimmed) else { return }

        query = trimmed
        remember(trimmed)

        if let model = webModel {
            model.updateSearchURL(url)
        } else {
            webModel = WebViewModel(tab: .search, fallbackTitle: "搜索", startURL: url)
        }
    }

    func clearHistory() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentKey)
    }

    func reloadAfterDataChange() {
        webModel?.reloadAfterDataChange()
    }

    private func remember(_ keyword: String) {
        var items = recentSearches.filter { $0.caseInsensitiveCompare(keyword) != .orderedSame }
        items.insert(keyword, at: 0)
        if items.count > maxRecentCount {
            items = Array(items.prefix(maxRecentCount))
        }
        recentSearches = items
        UserDefaults.standard.set(items, forKey: recentKey)
    }
}

struct SearchView: View {
    @ObservedObject var tabModel: SearchTabModel
    @ObservedObject var network: NetworkMonitor

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if let model = tabModel.webModel {
                WebContentView(model: model)
            } else {
                emptyState
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                TextField("搜索漫画名称", text: $tabModel.query)
                    .focused($isSearchFieldFocused)
                    .font(.system(size: 15))
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { performSearch(tabModel.query) }

                if !tabModel.query.isEmpty {
                    Button {
                        tabModel.query = ""
                        isSearchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                    .accessibilityLabel("清空搜索内容")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)

            Button("搜索") {
                performSearch(tabModel.query)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(tabModel.query.trimmingCharacters(in: .whitespaces).isEmpty
                             ? Color(UIColor.tertiaryLabel)
                             : .accentColor)
            .disabled(tabModel.query.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("搜索漫画")
                        .font(.title3.weight(.semibold))
                    Text("输入名称后在网站内搜索，例如「ONE PIECE」「鬼灭之刃」。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if !tabModel.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("最近搜索")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("清除") {
                                tabModel.clearHistory()
                            }
                            .font(.footnote)
                        }

                        FlexibleChipGrid(items: tabModel.recentSearches) { keyword in
                            performSearch(keyword)
                        }
                    }
                }

                if !network.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                        Text("当前无网络连接，搜索需要联网。")
                            .font(.footnote)
                    }
                    .foregroundColor(.orange)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func performSearch(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearchFieldFocused = false
        tabModel.search(trimmed)
    }
}

/// Simple wrapping chip layout that works on iOS 15 (no Layout protocol).
private struct FlexibleChipGrid: View {
    let items: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            Text(item)
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(UIColor.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Groups items into rows of at most three entries.
    private var rows: [[String]] {
        stride(from: 0, to: items.count, by: 3).map { index in
            Array(items[index..<min(index + 3, items.count)])
        }
    }
}
