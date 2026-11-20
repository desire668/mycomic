//
//  ReaderView.swift
//  MyComic
//
//  Native manga reader. Vertical continuous mode and horizontal page mode are
//  both rendered with plain SwiftUI views; images are downloaded, downsampled,
//  cached and prefetched by ImagePipeline.
//

import SwiftUI
import UIKit

// MARK: - Reader

struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var session: SessionViewModel

    @State private var showChapterList = false
    @State private var didRestoreScroll = false
    @State private var autoAdvancePending = false

    init(route: ReaderRoute) {
        _viewModel = StateObject(wrappedValue: ReaderViewModel(route: route))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.imageURLs.isEmpty {
                    stateContent
                } else {
                    if settings.readingMode == .vertical {
                        verticalReader(size: geometry.size)
                    } else {
                        pagedReader
                    }
                }

                if viewModel.showBars {
                    chrome
                        .transition(.opacity)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !viewModel.showBars)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.load()
            updateIdleTimer()
        }
        .onDisappear {
            viewModel.saveProgress()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: settings.keepScreenAwake) { _ in
            updateIdleTimer()
        }
        .sheet(isPresented: $showChapterList) {
            chapterListSheet
        }
    }

    // MARK: - States

    @ViewBuilder
    private var stateContent: some View {
        if let error = viewModel.error {
            ErrorStateView(error: error, onRetry: {
                viewModel.reload()
            }, onVerify: {
                session.presentVerification { viewModel.reload() }
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("正在加载章节图片…")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Vertical mode

    private func verticalReader(size: CGSize) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.imageURLs.enumerated()), id: \.offset) { index, url in
                        ReaderPageImage(
                            url: url,
                            width: size.width,
                            maxPixelSize: size.width * UIScreen.main.scale
                        )
                        .id(index)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: PageOffsetKey.self,
                                    value: [index: proxy.frame(in: .named("readerScroll")).minY]
                                )
                            }
                        )
                    }

                    chapterFooter
                }
                .padding(.bottom, viewModel.showBars ? 120 : 40)
            }
            .coordinateSpace(name: "readerScroll")
            .onPreferenceChange(PageOffsetKey.self) { values in
                updateVisiblePage(values, viewportHeight: size.height)
            }
            .onChange(of: viewModel.imageURLs.count) { _ in
                restoreScrollIfNeeded(proxy)
            }
            .simultaneousGesture(TapGesture().onEnded {
                toggleBars()
            })
        }
    }

    private func restoreScrollIfNeeded(_ proxy: ScrollViewProxy) {
        guard !didRestoreScroll, !viewModel.imageURLs.isEmpty else { return }
        didRestoreScroll = true
        autoAdvancePending = false
        let target = viewModel.currentIndex
        guard target > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    private func updateVisiblePage(_ values: [Int: CGFloat], viewportHeight: CGFloat) {
        guard !values.isEmpty else { return }

        let above = values.filter { $0.value <= 1 }
        let candidate: Int?
        if let current = above.max(by: { $0.value < $1.value }) {
            candidate = current.key
        } else if let first = values.min(by: { $0.value < $1.value }) {
            candidate = first.key
        } else {
            candidate = nil
        }

        guard let index = candidate else { return }
        if index != viewModel.currentIndex {
            viewModel.updateCurrentIndex(index)
        }

        if settings.autoLoadNextChapter,
           viewModel.currentIndex >= viewModel.imageURLs.count - 1,
           viewModel.hasNextChapter,
           !autoAdvancePending {
            autoAdvancePending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard settings.autoLoadNextChapter, viewModel.hasNextChapter else {
                    autoAdvancePending = false
                    return
                }
                didRestoreScroll = false
                viewModel.goToNextChapter()
                autoAdvancePending = false
            }
        }
    }

    private var chapterFooter: some View {
        VStack(spacing: 14) {
            if viewModel.isLoading {
                ProgressView().tint(.white)
            } else {
                Text("本章完")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 12) {
                Button("上一章") {
                    didRestoreScroll = false
                    viewModel.goToPreviousChapter()
                }
                .disabled(!viewModel.hasPreviousChapter)

                Button("下一章") {
                    didRestoreScroll = false
                    viewModel.goToNextChapter()
                }
                .disabled(!viewModel.hasNextChapter)

                Button("返回目录") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .font(.subheadline)
            .foregroundColor(.white)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Paged mode

    private var pagedReader: some View {
        TabView(selection: Binding(
            get: { viewModel.currentIndex },
            set: { newValue in
                viewModel.updateCurrentIndex(newValue)
            }
        )) {
            ForEach(Array(viewModel.imageURLs.enumerated()), id: \.offset) { index, url in
                ZoomablePage(url: url)
                    .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .background(Color.black)
        .simultaneousGesture(TapGesture().onEnded {
            toggleBars()
        })
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack {
            topBar
            Spacer()
            bottomBar
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.comicTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(viewModel.chapterTitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Text(viewModel.progressText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.85), Color.black.opacity(0)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if viewModel.imageURLs.count > 1 {
                ProgressView(value: Double(viewModel.currentIndex + 1), total: Double(viewModel.imageURLs.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            }

            HStack(spacing: 18) {
                Button {
                    didRestoreScroll = false
                    viewModel.goToPreviousChapter()
                } label: {
                    bottomIcon("backward.end.fill", title: "上一章", enabled: viewModel.hasPreviousChapter)
                }
                .disabled(!viewModel.hasPreviousChapter)

                Button {
                    showChapterList = true
                } label: {
                    bottomIcon("list.bullet", title: "目录", enabled: true)
                }

                Button {
                    settings.readingMode = settings.readingMode == .vertical ? .paged : .vertical
                    if settings.readingMode == .vertical { didRestoreScroll = false }
                } label: {
                    bottomIcon(settings.readingMode == .vertical ? "rectangle.portrait" : "rectangle.grid.1x2",
                               title: settings.readingMode == .vertical ? "单页" : "纵向",
                               enabled: true)
                }

                Button {
                    didRestoreScroll = false
                    viewModel.goToNextChapter()
                } label: {
                    bottomIcon("forward.end.fill", title: "下一章", enabled: viewModel.hasNextChapter)
                }
                .disabled(!viewModel.hasNextChapter)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 26)
        .background(
            LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.9)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
    }

    private func bottomIcon(_ systemName: String, title: String, enabled: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
            Text(title)
                .font(.caption2)
        }
        .foregroundColor(enabled ? .white : .white.opacity(0.3))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chapter list

    private var chapterListSheet: some View {
        NavigationView {
            List {
                ForEach(viewModel.chapters) { chapter in
                    Button {
                        showChapterList = false
                        didRestoreScroll = false
                        viewModel.switchChapter(chapter.id)
                    } label: {
                        HStack {
                            Text(chapter.title)
                                .foregroundColor(.primary)
                            Spacer()
                            if chapter.id == viewModel.chapterId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("章节列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        showChapterList = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggleBars() {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.showBars.toggle()
        }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake
    }
}

// MARK: - Page offset tracking

private struct PageOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Vertical page

struct ReaderPageImage: View {
    let url: URL
    let width: CGFloat
    let maxPixelSize: CGFloat

    @StateObject private var loader = RemoteImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(CGSize(width: image.size.width, height: image.size.height), contentMode: .fit)
                    .frame(width: width)
            } else {
                ZStack {
                    Color.black
                    if loader.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.gray)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                            Text("图片加载失败")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                    }
                }
                .frame(width: width, height: width * 1.4)
            }
        }
        .task(id: url) {
            loader.load(url: url, maxPixelSize: maxPixelSize)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

// MARK: - Paged / zoomable page

struct ZoomablePage: View {
    let url: URL

    @StateObject private var loader = RemoteImageLoader()
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if loader.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.gray)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                        Text("图片加载失败")
                            .font(.caption2)
                    }
                    .foregroundColor(.gray)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value, 1), 4)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1 {
                            resetZoom(animated: true)
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = scale > 1 ? offset : .zero
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if scale > 1 {
                        scale = 1
                        lastScale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.4
                        lastScale = 2.4
                    }
                }
            }
        }
        .task(id: url) {
            resetZoom(animated: false)
            loader.load(url: url, maxPixelSize: UIScreen.main.bounds.width * UIScreen.main.scale * 2)
        }
        .onDisappear {
            loader.cancel()
        }
    }

    private func resetZoom(animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                scale = 1
                lastScale = 1
                offset = .zero
                lastOffset = .zero
            }
        } else {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }
}
