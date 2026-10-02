//
//  DailyQuestsCard.swift
//  LanguageApp
//
//  Today's quests at the top of the learning path: progress bars + XP rewards.
//

import SwiftUI
import SwiftData

struct DailyQuestsCard: View {
    @Environment(UserSettings.self) private var userSettings
    @Query private var activities: [DailyActivity]

    var body: some View {
        let theme = userSettings.theme
        // Reading `.now` here is enough: the card is rebuilt whenever today's activity changes
        // and when the app comes back to the foreground.
        let dayKey = ProgressService.dayKey(for: .now)
        let today = activities.first { $0.dayKey == dayKey }
        let quests = DailyQuestService.quests(for: today, dayKey: dayKey, dailyGoalXP: userSettings.dailyGoalXP)
        let doneCount = quests.filter { DailyQuestService.isComplete($0, in: today) }.count

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("daily_quests".localized(), systemImage: "target")
                    .font(mainFont.bold(17))
                    .foregroundStyle(theme.textColor)
                Spacer()
                Text("\(doneCount)/\(quests.count)")
                    .setFont(.bold, size: 15, color: doneCount == quests.count ? theme.correctColor : theme.secondaryTextColor)
            }

            if doneCount == quests.count {
                Label("quests_all_done".localized(), systemImage: "checkmark.seal.fill")
                    .font(mainFont.semibold(15))
                    .foregroundStyle(theme.correctShadowColor)
            } else {
                ForEach(quests) { quest in
                    row(quest, progress: DailyQuestService.progress(of: quest, in: today))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(_ quest: DailyQuest, progress: Int) -> some View {
        let theme = userSettings.theme
        let isDone = progress >= quest.target
        return HStack(spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : quest.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isDone ? theme.correctColor : theme.xpColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(quest.title)
                        .setFont(.semibold, size: 15, color: theme.textColor)
                    Spacer()
                    Text("xp_earned".localizedFormat(quest.rewardXP))
                        .setFont(.bold, size: 13, color: isDone ? theme.secondaryTextColor : theme.xpColor)
                }
                HStack(spacing: 8) {
                    LessonProgressBar(progress: Double(min(progress, quest.target)) / Double(quest.target),
                                      height: 10,
                                      color: isDone ? theme.correctColor : theme.xpColor)
                    Text("\(min(progress, quest.target))/\(quest.target)")
                        .setFont(.semibold, size: 12, color: theme.secondaryTextColor)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DailyQuestsCard()
        .padding()
        .environment(UserSettings())
        .modelContainer(PersistenceController.preview)
}
