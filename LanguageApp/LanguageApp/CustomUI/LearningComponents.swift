//
//  LearningComponents.swift
//  LanguageApp
//
//  Small reusable views: progress bar, stat pill, speaker button, card container.
//

import SwiftUI

struct LessonProgressBar: View {
    @Environment(UserSettings.self) private var userSettings
    var progress: Double
    var height: CGFloat = 16
    var color: Color?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(userSettings.theme.cardBgColor)
                Capsule()
                    .fill(color ?? userSettings.theme.correctColor)
                    .frame(width: max(height, proxy.size.width * min(max(progress, 0), 1)))
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: height * 0.25)
                            .padding(.horizontal, 8)
                            .padding(.top, 3)
                    }
                    .opacity(progress <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
    }
}

/// Icon + value pill (streak, XP, hearts…)
struct StatPill: View {
    @Environment(UserSettings.self) private var userSettings
    let systemImage: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(mainFont.bold(18))
                .foregroundStyle(color)
            Text(value)
                .setFont(.bold, size: 16, color: color)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(userSettings.theme.cardBgColor, in: Capsule())
    }
}

/// Round speaker button that reads `text` with TTS.
struct SpeakerButton: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(SpeechService.self) private var speech
    let text: String
    let locale: String
    var size: CGFloat = 44
    var slow: Bool = false

    var body: some View {
        Button {
            speech.speak(text, locale: locale, slow: slow)
        } label: {
            Image(systemName: slow ? "tortoise.fill" : "speaker.wave.2.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(userSettings.theme.primaryColor, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("play_audio".localized())
    }
}

/// Example sentence with its translation and buttons to hear the whole sentence (normal / slow).
struct ExampleSentenceView: View {
    @Environment(UserSettings.self) private var userSettings
    let example: String
    let meaning: String?
    let locale: String

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 8) {
            Text(example)
                .setFont(.medium, size: 16, color: theme.textColor, alignment: .center)
            HStack(spacing: 10) {
                SpeakerButton(text: example, locale: locale, size: 34)
                SpeakerButton(text: example, locale: locale, size: 34, slow: true)
            }
            if let meaning, !meaning.isEmpty {
                Text(meaning)
                    .setFont(.regular, size: 14, color: theme.secondaryTextColor, alignment: .center)
            }
        }
    }
}

/// Rounded card container used by lists & stats.
struct CardContainer<Content: View>: View {
    @Environment(UserSettings.self) private var userSettings
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(userSettings.theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Screen title used on tab roots.
struct ScreenTitle: View {
    @Environment(UserSettings.self) private var userSettings
    let title: String

    var body: some View {
        Text(title)
            .setFont(.bold, size: 28, color: userSettings.theme.textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
