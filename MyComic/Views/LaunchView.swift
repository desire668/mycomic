//
//  LaunchView.swift
//  MyComic
//
//  Native splash screen. It is shown until the home page has finished its first
//  load (or a short timeout), which guarantees that the user never stares at a
//  blank white web view.
//

import SwiftUI

struct LaunchView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.11, blue: 0.18),
                    Color(red: 0.16, green: 0.19, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                logoView
                    .scaleEffect(isAnimating ? 1 : 0.9)
                    .opacity(isAnimating ? 1 : 0.6)

                VStack(spacing: 6) {
                    Text("MyComic")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("漫画阅读")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(4)
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.85)))
                    .padding(.top, 10)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MyComic 正在启动")
    }

    private var logoView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 108, height: 108)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.36, blue: 0.20),
                            Color(red: 0.85, green: 0.18, blue: 0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
            Text("M")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

struct LaunchView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchView()
    }
}
