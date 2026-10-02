//
//  StreakView.swift
//  LanguageApp
//
//  Streak details (sheet from the flame in the Learn header): current streak,
//  the last 7 days (studied / frozen / missed) and the streak freeze shop.
//

import SwiftUI
import SwiftData

struct StreakCoordinator: View {
    var navRouter: any NavRouterProtocol

    var body: some View {
        StreakView(onClose: { navRouter.dismiss() },
                   onOpenPaywall: { navRouter.showSheet(RouterView(routable: Router.Study.paywall)) })
    }
}

struct StreakView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(GamificationManager.self) private var gamification
    @Environment(PremiumManager.self) private var premium
    @Query private var activities: [DailyActivity]

    var onClose: VoidResult?
    var onOpenPaywall: VoidResult?

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { onClose?() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 24) {
                    header
                    WeekStreakRow(activities: activities)
                    freezeCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
    }

    // MARK: - Header

    private var header: some View {
        let theme = userSettings.theme
        return VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.streakColor)
            Text("\(ProgressService.streak(from: activities))")
                .setFont(.bold, size: 48, color: theme.streakColor, alignment: .center)
                .monospacedDigit()
            Text("day_streak".localized())
                .setFont(.bold, size: 18, color: theme.textColor, alignment: .center)
            Text("streak_keep_going".localized())
                .setFont(.regular, size: 15, color: theme.secondaryTextColor, alignment: .center)
        }
    }

    // MARK: - Streak freeze

    private var freezeCard: some View {
        let theme = userSettings.theme
        let isPremium = premium.isPremium
        let owned = gamification.availableStreakFreezes(isPremium: isPremium)
        let maxFreezes = GamificationManager.maxStreakFreezes
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "snowflake")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.freezeColor)
                Text("streak_freeze".localized())
                    .setFont(.bold, size: 18, color: theme.textColor)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<maxFreezes, id: \.self) { index in
                        Image(systemName: "snowflake.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(index < owned ? theme.freezeColor : theme.lockedColor)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("streak_freeze_owned".localizedFormat(owned, maxFreezes))
            }

            Text("streak_freeze_desc".localized())
                .setFont(.regular, size: 15, color: theme.secondaryTextColor)

            Text("streak_freeze_owned".localizedFormat(owned, maxFreezes))
                .setFont(.semibold, size: 15, color: theme.textColor)

            if isPremium {
                Label("streak_freeze_plus_active".localized(), systemImage: "crown.fill")
                    .font(mainFont.semibold(15))
                    .foregroundStyle(theme.xpColor)
            } else {
                buySection
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var buySection: some View {
        let theme = userSettings.theme
        let totalXP = ProgressService.totalXP(from: activities)
        let status = gamification.canBuyStreakFreeze(totalXP: totalXP)

        Button {
            if gamification.buyStreakFreeze(totalXP: totalXP) == .bought {
                FeedbackService.tap()
            }
        } label: {
            Label("streak_freeze_buy".localizedFormat(GamificationManager.streakFreezeCost), systemImage: "bolt.fill")
        }
        .filled(theme.freezeColor)
        .disabled(status != .bought)

        Group {
            switch status {
            case .alreadyFull:
                Text("streak_freeze_full".localized())
            case .notEnoughXP:
                Text("streak_freeze_not_enough_xp".localized())
            case .bought:
                EmptyView()
            }
        }
        .font(mainFont.semibold(14))
        .foregroundStyle(theme.secondaryTextColor)
        .frame(maxWidth: .infinity)

        Text("streak_freeze_balance".localizedFormat(gamification.xpBalance(totalXP: totalXP)))
            .setFont(.regular, size: 13, color: theme.secondaryTextColor, alignment: .center)
            .frame(maxWidth: .infinity)

        Button("streak_freeze_plus_hint".localized()) { onOpenPaywall?() }
            .buttonStyle(TextButtonStyle(color: theme.primaryColor))
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Last 7 days

private struct WeekStreakRow: View {
    @Environment(UserSettings.self) private var userSettings
    let activities: [DailyActivity]

    private enum DayState { case studied, frozen, missed, today }

    private struct Day: Identifiable {
        let date: Date
        let state: DayState
        var id: Date { date }
    }

    private var days: [Day] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let active = ProgressService.activeDayKeys(from: activities)
        let frozen = ProgressService.frozenDayKeys(from: activities)
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = ProgressService.dayKey(for: date, calendar: calendar)
            if active.contains(key) { return Day(date: date, state: .studied) }
            if frozen.contains(key) { return Day(date: date, state: .frozen) }
            return Day(date: date, state: offset == 0 ? .today : .missed)
        }
    }

    var body: some View {
        let theme = userSettings.theme
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.date, format: .dateTime.weekday(.narrow))
                        .setFont(.semibold, size: 13, color: theme.secondaryTextColor)
                    icon(for: day.state)
                        .font(.system(size: 24))
                        .frame(height: 30)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func icon(for state: DayState) -> some View {
        let theme = userSettings.theme
        switch state {
        case .studied:
            Image(systemName: "flame.fill").foregroundStyle(theme.streakColor)
        case .frozen:
            Image(systemName: "snowflake").foregroundStyle(theme.freezeColor)
        case .missed:
            Image(systemName: "circle").foregroundStyle(theme.lockedColor)
        case .today:
            Image(systemName: "circle.dashed").foregroundStyle(theme.streakColor)
        }
    }
}

#Preview {
    StreakView()
        .environment(UserSettings())
        .environment(GamificationManager())
        .environment(PremiumManager())
        .modelContainer(PersistenceController.preview)
}
