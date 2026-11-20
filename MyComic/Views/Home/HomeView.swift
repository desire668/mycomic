//
//  HomeView.swift
//  MyComic
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var session: SessionViewModel
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    brandingHeader
                    continueReadingCard
                    stateContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                viewModel.reload()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadIfNeeded()
        }
    }

    // MARK: - Header

    private var brandingHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(colors: [Color.orange, Color.red.opacity(0.85)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("MyComic")
                    .font(.title2)
                    .fontWeight(.heavy)
                Text("原生漫画客户端 · 数据来自 mycomic.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var continueReadingCard: some View {
        if let record = library.continueReading {
            NavigationLink(destination: ReaderView(route: ReaderRoute(
                comicId: record.comicId,
                comicTitle: record.comicTitle,
                coverURLString: record.coverURLString,
                chapterId: record.chapterId,
                chapterTitle: record.chapterTitle
            ))) {
                HStack(spacing: 12) {
                    RemoteImageView(urlString: record.coverURLString, maxPixelSize: 320)
                        .frame(width: 54, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("继续阅读")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(record.comicTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(record.progressText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var stateContent: some View {
        if let feed = viewModel.feed {
            VStack(alignment: .leading, spacing: 24) {
                if let error = viewModel.error {
                    inlineError(error)
                }

                comicSection(
                    title: "最近更新",
                    subtitle: "按更新时间排序",
                    comics: feed.recentUpdates,
                    more: AnyView(ComicListView(title: "最近更新", sort: .updated))
                )

                comicSection(
                    title: "最新上架",
                    subtitle: "最新收录的作品",
                    comics: feed.latest,
                    more: AnyView(ComicListView(title: "最新上架", sort: .newest))
                )

                comicSection(
                    title: "人气推荐",
                    subtitle: "按浏览量排序",
                    comics: feed.popular,
                    more: AnyView(ComicListView(title: "最高人气", sort: .popular))
                )
            }
        } else if let error = viewModel.error {
            ErrorStateView(error: error, onRetry: {
                viewModel.reload()
            }, onVerify: {
                session.presentVerification { viewModel.reload() }
            })
            .frame(minHeight: 420)
        } else {
            VStack(spacing: 14) {
                ProgressView()
                Text("正在获取漫画数据…")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 380)
        }
    }

    private func inlineError(_ error: AppError) -> some View {
        HStack(spacing: 10) {
            Image(systemName: error.isCloudflare ? "hand.raised" : "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer()
            Button("重试") {
                viewModel.reload()
            }
            .font(.caption)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func comicSection(title: String, subtitle: String, comics: [Comic], more: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, subtitle: subtitle, moreDestination: more)
            ComicGrid(comics: Array(comics.prefix(9)))
        }
    }
}
