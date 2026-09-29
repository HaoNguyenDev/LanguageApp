//
//  LoadingView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI


#Preview {
    TestLoadingView()
        .environment(UserSettings())
}

struct TestLoadingView: View {
    var body: some View {
        VStack {
            LoadingView(hideText: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
    }
}

struct LoadingView: View {
    @Environment(UserSettings.self) var userSettings
    @State private var isAnimating = false
    private let dotCount = 6
    private let radius: CGFloat = 30
    var hideText: Bool = false
    var loadingOnSubview: Bool = false

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(loadingOnSubview ? userSettings.theme.textOnSubviewColor : userSettings.theme.textColor)
                    .frame(width: 10, height: 10)
                    .offset(x: radius)
                    .rotationEffect(.degrees(Double(index) / Double(dotCount) * 360))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.05),
                        value: isAnimating
                    )
            }
            
            if !hideText {
                VStack {
                    Text("please_wait".localized())
                        .setFont(.bold, size: 17, color: userSettings.theme.textColor)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 120)
            }
        }
        
        
        .onAppear {
            isAnimating = true
        }
    }
}
