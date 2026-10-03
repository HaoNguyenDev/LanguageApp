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
    @State private var hideTask: Task<Void, Never>?

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

    /// Long (reading) toasts can be closed right away so they don't cover what the learner is looking at.
    private var isClosable: Bool { message.duration != nil }

    @ViewBuilder
    private var closeButton: some View {
        if isClosable {
            Button {
                hide(animation: .easeOut(duration: 0.2))
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(userSettings.theme.textOnSubviewColor.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(userSettings.theme.textOnSubviewColor.opacity(0.1), in: .circle)
                    .frame(width: 44, height: 44) // comfortable tap target
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(2)
            .accessibilityLabel("close".localized())
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
            // Room for the close button so it never covers the title.
            .padding(.trailing, isClosable ? 24 : 0)
            .background(userSettings.theme.subviewBgColor, in: .rect(cornerRadius: 20))
            .overlay(alignment: .topTrailing) { closeButton }
            // System default spacing around the card, so it never touches the screen edges.
            .padding()
            .opacity(opacity)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 0.2)) {
                self.opacity = 1
            }
            isAnimating = true
            autoHide(after: message.duration ?? TimeInterval(kShowDuration))
        }
        .onChange(of: opacity) { _, newVal in
            if opacity == 0 && isAnimating {
                isAnimating = false
                didHideMessage?(message)
            }
        }
    }

    private func autoHide(after seconds: TimeInterval) {
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            // Long (reading) toasts fade out gently.
            hide(animation: .easeOut(duration: message.duration == nil ? 0.2 : 0.6))
        }
    }

    /// Fades out; `onChange(of: opacity)` then tells the queue to show the next toast.
    private func hide(animation: Animation) {
        hideTask?.cancel()
        hideTask = nil
        guard isAnimating, opacity > 0 else { return }
        withAnimation(animation) {
            self.opacity = 0
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
