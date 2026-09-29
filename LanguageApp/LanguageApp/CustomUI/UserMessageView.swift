//
//  UserMessageView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//


import SwiftUI
import UIKit

struct UserMessageView: View {
    @Environment(UserSettings.self) var userSettings
    private let kShowDuration: Int = 3  // Second
    @State private var opacity: CGFloat = 0
    @State private var isAnimating = false

    private let showAnimation = Animation.bouncy(
        duration: 0.1,
        extraBounce: 0.4)
    private let hideAnimation = Animation.linear(duration: 0.1)

    let message: UserMessageItem

    var didHideMessage: ((UserMessageItem) -> Void)?

    init(message: UserMessageItem, completion: ((UserMessageItem) -> Void)?) {
        self.message = message
        self.didHideMessage = completion
    }

    var body: some View {
        toastView
    }

    @ViewBuilder
    var icon: some View {
        if let icon = message.icon {
            Image(uiImage: icon)
                .resizable()
                .frame(width: 72, height: 72)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    var titleLabel: some View {
        if let title = message.title {
            Text(title)
                .setFont(.bold, size: 20, color: userSettings.theme.textOnSubviewColor)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    var animationView: some View {
        if let animation = message.animation {
            LottieHelperView(
                fileName: animation.name,
                playLoopMode: animation.loop
            )
            .frame(width: 72, height: 72)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    var toastView: some View {
        VStack {
            HStack(spacing: 8) {
                animationView
                VStack(alignment: .leading, spacing: 8) {
                    icon
                    titleLabel
                    if let message = message.message {
                        Text(message)
                            .setFont(.regular, size: 14, color: userSettings.theme.textOnSubviewColor)
                    } else if let message = message.attributeMessage {
                        Text(message)
                    }

                }
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(userSettings.theme.textOnSubviewColor)
            .padding(16)
            .background(userSettings.theme.subviewBgColor, in: .rect(cornerRadius: 20))
            .opacity(opacity)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 0.2)) {
                self.opacity = 1
            }
            isAnimating = true
            autoHide(after: kShowDuration)
        }
        .onChange(of: opacity) { _, newVal in
            if opacity == 0 && isAnimating {
                isAnimating = false
                didHideMessage?(message)
            }
        }
    }

    private func autoHide(after second: Int) {
        Task { @MainActor in
            try await Task.sleep(for: .seconds(second))
            withAnimation(.linear(duration: 0.2)) {
                self.opacity = 0
            }
        }
    }
}

#Preview {
    return UserMessageView(
        message: UserMessageItem(
            title: "Test title",
            message: "Test message"),
        completion: nil)
}
