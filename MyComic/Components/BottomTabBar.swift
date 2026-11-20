//
//  BottomTabBar.swift
//  MyComic
//
//  Custom native-styled tab bar. A custom bar (instead of UITabBar) lets the
//  reader enter a true full-screen mode on iOS 15 and keeps the layout identical
//  on iPhone and iPad.
//

import SwiftUI
import UIKit

struct BottomTabBar: View {
    @Binding var selection: WebTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WebTab.allCases) { tab in
                tabItem(tab)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            Color(UIColor.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            Divider(),
            alignment: .top
        )
    }

    private func tabItem(_ tab: WebTab) -> some View {
        let isSelected = selection == tab
        return Button {
            guard selection != tab else { return }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.easeOut(duration: 0.15)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIconName : tab.iconName)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .frame(height: 22)
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .accentColor : Color(UIColor.secondaryLabel))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
