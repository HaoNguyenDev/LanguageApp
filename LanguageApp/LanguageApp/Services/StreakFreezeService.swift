//
//  StreakFreezeService.swift
//  LanguageApp
//
//  Covers missed days with streak freezes so the streak survives.
//  Runs when the app becomes active: if every day between the last kept day
//  (activity or freeze) and today can be covered, those days are marked frozen.
//

import Foundation
import SwiftData

enum StreakFreezeService {
    /// How far back to look for the last kept day.
    static let lookBackDays = 60

    struct Gap: Equatable {
        /// Last day that kept the streak (activity or freeze).
        let lastKeptDayKey: String
        /// Missed days after it, oldest first (today is never missed – there's still time to study).
        let missedDays: [Date]
    }

    // MARK: - Pure calculations (unit tested)

    /// Missed days since the last kept day; nil when nothing was missed or there is no streak to save.
    static func gap(activeDayKeys: Set<String>,
                    frozenDayKeys: Set<String>,
                    today: Date = .now,
                    calendar: Calendar = .current) -> Gap? {
        let keptDayKeys = activeDayKeys.union(frozenDayKeys)
        let start = calendar.startOfDay(for: today)
        var missed: [Date] = []
        for offset in 1...lookBackDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { break }
            let key = ProgressService.dayKey(for: day, calendar: calendar)
            if keptDayKeys.contains(key) {
                return missed.isEmpty ? nil : Gap(lastKeptDayKey: key, missedDays: missed.reversed())
            }
            missed.append(day)
        }
        return nil
    }

    /// Whether the freezes available can cover the whole gap. A gap longer than
    /// `maxStreakFreezes` days is never covered (also for Plus).
    static func canCover(_ gap: Gap, availableFreezes: Int, lostAfterDayKey: String?) -> Bool {
        guard gap.lastKeptDayKey != lostAfterDayKey else { return false }
        let days = gap.missedDays.count
        return days <= GamificationManager.maxStreakFreezes && days <= availableFreezes
    }

    // MARK: - Persistence

    /// Freezes the missed days if possible.
    /// - Returns: number of days frozen (0 when nothing was missed or the streak is lost).
    @discardableResult
    static func applyIfNeeded(in context: ModelContext,
                              gamification: GamificationManager,
                              isPremium: Bool,
                              now: Date = .now,
                              calendar: Calendar = .current) -> Int {
        let activities = ProgressService.allActivities(in: context)
        guard let gap = gap(activeDayKeys: ProgressService.activeDayKeys(from: activities),
                            frozenDayKeys: ProgressService.frozenDayKeys(from: activities),
                            today: now,
                            calendar: calendar) else { return 0 }

        guard canCover(gap,
                       availableFreezes: gamification.availableStreakFreezes(isPremium: isPremium),
                       lostAfterDayKey: gamification.streakLostAfterDayKey) else {
            // Remember the lost streak so freezes bought later can't revive it.
            gamification.streakLostAfterDayKey = gap.lastKeptDayKey
            return 0
        }

        for day in gap.missedDays {
            let key = ProgressService.dayKey(for: day, calendar: calendar)
            if let existing = activities.first(where: { $0.dayKey == key }) {
                existing.streakFreezeUsed = true
            } else {
                let activity = DailyActivity(dayKey: key, date: day)
                activity.streakFreezeUsed = true
                context.insert(activity)
            }
        }
        try? context.save()
        gamification.useStreakFreezes(gap.missedDays.count, isPremium: isPremium)
        Logger.shared.info("Streak freeze used for \(gap.missedDays.count) day(s)")
        return gap.missedDays.count
    }
}
