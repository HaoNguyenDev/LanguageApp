//
//  LessonResultView.swift
//  LanguageApp
//

import SwiftUI
import Lottie

struct LessonResultView: View {
    @Environment(UserSettings.self) private var userSettings
    let result: LessonResult
    var onContinue: VoidResult?

    @State private var appear = false

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 20) {
            Spacer()
            LottieHelperView(fileName: result.isPerfect ? "Win" : "Congrats", playLoopMode: .playOnce)
                .frame(width: 220, height: 220)

            Text((result.isPerfect ? "lesson_perfect" : "lesson_complete").localized())
                .setFont(.bold, size: 30, color: theme.xpColor, alignment: .center)

            if result.reachedDailyGoal {
                Label("daily_goal_reached".localized(), systemImage: "target")
                    .font(mainFont.bold(15))
                    .foregroundStyle(theme.correctShadowColor)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(theme.correctBgColor, in: Capsule())
            }

            HStack(spacing: 12) {
                statTile(title: "total_xp".localized(), value: "+\(result.xpEarned)",
                         icon: "bolt.fill", color: theme.xpColor)
                statTile(title: "accuracy".localized(), value: "\(Int((result.accuracy * 100).rounded()))%",
                         icon: "scope", color: theme.correctColor)
                statTile(title: "streak".localized(), value: "\(result.streak)",
                         icon: "flame.fill", color: theme.streakColor)
            }
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)

            if result.newWords > 0 {
                Text("new_words_learned".localizedFormat(result.newWords))
                    .setFont(.medium, size: 15, color: theme.secondaryTextColor, alignment: .center)
            }
            Spacer()
            Button("continue".localized()) { onContinue?() }
                .filled(theme.primaryColor)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) { appear = true }
        }
    }

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(title.uppercased())
                .setFont(.bold, size: 11, color: .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(color)
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(value)
                    .font(mainFont.bold(20))
            }
            .foregroundStyle(color)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(userSettings.theme.bgColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color, lineWidth: 2))
    }
}

#Preview {
    LessonResultView(result: LessonResult(xpEarned: 15, accuracy: 1, newWords: 6, streak: 3,
                                          isPerfect: true, reachedDailyGoal: true))
        .environment(UserSettings())
}
