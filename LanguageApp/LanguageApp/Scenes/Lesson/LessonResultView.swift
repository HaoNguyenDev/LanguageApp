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
            if result.checkpoint?.passed == false {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(theme.streakColor)
                    .frame(width: 220, height: 220)
            } else {
                LottieHelperView(fileName: result.isPerfect || result.checkpoint != nil ? "Win" : "Congrats",
                                 playLoopMode: .playOnce)
                    .frame(width: 220, height: 220)
            }

            Text(titleKey.localized())
                .setFont(.bold, size: 30, color: result.checkpoint?.passed == false ? theme.streakColor : theme.xpColor,
                         alignment: .center)

            if let checkpoint = result.checkpoint {
                Text(checkpointMessage(checkpoint))
                    .setFont(.medium, size: 16, color: theme.secondaryTextColor, alignment: .center)
            }

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

            if !result.completedQuests.isEmpty {
                completedQuests
                    .opacity(appear ? 1 : 0)
            }

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

    private var titleKey: String {
        if let checkpoint = result.checkpoint {
            return checkpoint.passed ? "checkpoint_passed" : "checkpoint_failed"
        }
        return result.isPerfect ? "lesson_perfect" : "lesson_complete"
    }

    private func checkpointMessage(_ checkpoint: CheckpointOutcome) -> String {
        if !checkpoint.passed {
            return "checkpoint_failed_message".localizedFormat(Int((checkpoint.requiredAccuracy * 100).rounded()))
        }
        return (checkpoint.unlockedNextUnit ? "checkpoint_next_unit_unlocked" : "checkpoint_passed_again").localized()
    }

    private var completedQuests: some View {
        let theme = userSettings.theme
        return VStack(alignment: .leading, spacing: 8) {
            Label("quest_complete_title".localized(), systemImage: "checkmark.seal.fill")
                .font(mainFont.bold(15))
                .foregroundStyle(theme.correctShadowColor)
            ForEach(result.completedQuests) { quest in
                HStack(spacing: 10) {
                    Image(systemName: quest.icon)
                        .foregroundStyle(theme.xpColor)
                        .frame(width: 22)
                    Text(quest.title)
                        .setFont(.semibold, size: 15, color: theme.textColor)
                    Spacer()
                    Text("xp_earned".localizedFormat(quest.rewardXP))
                        .setFont(.bold, size: 15, color: theme.xpColor)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.correctBgColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                                          isPerfect: true, reachedDailyGoal: true,
                                          completedQuests: [DailyQuestService.quest(.perfectLesson, dailyGoalXP: 20)]))
        .environment(UserSettings())
}
