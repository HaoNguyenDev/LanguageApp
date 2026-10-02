//
//  LearnHeaderView.swift
//  LanguageApp
//
//  Top bar: current course flag · streak · XP · hearts.
//

import SwiftUI
import SwiftData

struct LearnHeaderView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(GamificationManager.self) private var gamification
    @Environment(PremiumManager.self) private var premium
    @Query private var activities: [DailyActivity]

    let course: Course?
    var onChangeCourse: VoidResult?
    var onTapHearts: VoidResult?
    var onTapStreak: VoidResult?

    var body: some View {
        let theme = userSettings.theme
        HStack(spacing: 8) {
            Button {
                onChangeCourse?()
            } label: {
                HStack(spacing: 4) {
                    if let course {
                        LanguageBadge(courseId: course.remoteId, size: 28)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(theme.primaryColor)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondaryTextColor)
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(theme.cardBgColor, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            Button {
                onTapStreak?()
            } label: {
                StatPill(systemImage: "flame.fill",
                         value: "\(ProgressService.streak(from: activities))",
                         color: theme.streakColor)
            }
            .buttonStyle(.plain)
            StatPill(systemImage: "bolt.fill",
                     value: "\(ProgressService.totalXP(from: activities))",
                     color: theme.xpColor)
            Button {
                onTapHearts?()
            } label: {
                StatPill(systemImage: "heart.fill",
                         value: premium.isPremium ? "∞" : "\(gamification.hearts)",
                         color: theme.heartColor)
            }
            .buttonStyle(.plain)
        }
    }
}
