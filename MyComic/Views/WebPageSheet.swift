//
//  WebPageSheet.swift
//  MyComic
//
//  Modal browser used for secondary pages (records, ranking, …). The web view
//  is created when the sheet appears and released when it is dismissed.
//

import SwiftUI

struct WebDestination: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

struct WebPageSheet: View {
    let destination: WebDestination

    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var model: WebViewModel

    init(destination: WebDestination) {
        self.destination = destination
        _model = StateObject(wrappedValue: WebViewModel(
            fallbackTitle: destination.title,
            startURL: destination.url
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ProgressBar(progress: model.progress)
                WebContentView(model: model)
            }
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onDisappear {
            model.dispose()
        }
    }
}
