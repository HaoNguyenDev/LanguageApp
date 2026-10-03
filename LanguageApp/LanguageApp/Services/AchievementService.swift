//
//  AchievementService.swift
//  LanguageApp
//
//  Achievements: unlocked once and kept forever (stored with the unlock date), even if the
//  condition stops being true later (e.g. a streak that ends). Checked after lessons, practice,
//  checkpoints, reviews and when the app becomes active; new ones are celebrated.
//

import Foundation
import SwiftData

/// What achievements are measured on.
struct AchievementStats: Equatable {
    var bestStreak = 0
    var totalXP = 0
    var wordsLearned = 0
    var lessonsCompleted = 0
    var perfectLessons = 0
    var reviewsDone = 0
    var checkpointsPassed = 0
    /// Days on which every daily quest was completed.
    var questDaysCompleted = 0
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let icon: String
    let titleKey: String
    let descriptionKey: String
    let condition: Condition

    enum Condition: Hashable {
        case lessons(Int), perfectLessons(Int), bestStreak(Int), words(Int), xp(Int)
        case reviews(Int), checkpoints(Int), questDays(Int)
    }

    func isUnlocked(_ stats: AchievementStats) -> Bool {
        let (value, target) = progress(stats)
        return value >= target
    }

    /// Current value and target (for progress bars).
    func progress(_ stats: AchievementStats) -> (value: Int, target: Int) {
        switch condition {
        case .lessons(let n): return (stats.lessonsCompleted, n)
        case .perfectLessons(let n): return (stats.perfectLessons, n)
        case .bestStreak(let n): return (stats.bestStreak, n)
        case .words(let n): return (stats.wordsLearned, n)
        case .xp(let n): return (stats.totalXP, n)
        case .reviews(let n): return (stats.reviewsDone, n)
        case .checkpoints(let n): return (stats.checkpointsPassed, n)
        case .questDays(let n): return (stats.questDaysCompleted, n)
        }
    }

    static let all: [Achievement] = [
        Achievement(id: "first_lesson", icon: "flag.checkered", titleKey: "ach_first_lesson", descriptionKey: "ach_first_lesson_desc", condition: .lessons(1)),
        Achievement(id: "perfect", icon: "star.fill", titleKey: "ach_perfect", descriptionKey: "ach_perfect_desc", condition: .perfectLessons(1)),
        Achievement(id: "streak3", icon: "flame.fill", titleKey: "ach_streak_3", descriptionKey: "ach_streak_3_desc", condition: .bestStreak(3)),
        Achievement(id: "streak7", icon: "flame.circle.fill", titleKey: "ach_streak_7", descriptionKey: "ach_streak_7_desc", condition: .bestStreak(7)),
        Achievement(id: "words50", icon: "character.book.closed.fill", titleKey: "ach_words_50", descriptionKey: "ach_words_50_desc", condition: .words(50)),
        Achievement(id: "xp500", icon: "bolt.circle.fill", titleKey: "ach_xp_500", descriptionKey: "ach_xp_500_desc", condition: .xp(500)),
        Achievement(id: "first_checkpoint", icon: "trophy.fill", titleKey: "ach_first_checkpoint", descriptionKey: "ach_first_checkpoint_desc", condition: .checkpoints(1)),
        Achievement(id: "quest_day", icon: "target", titleKey: "ach_quest_day", descriptionKey: "ach_quest_day_desc", condition: .questDays(1)),
        Achievement(id: "reviews100", icon: "rectangle.stack.fill", titleKey: "ach_reviews_100", descriptionKey: "ach_reviews_100_desc", condition: .reviews(100)),
        Achievement(id: "perfect10", icon: "sparkles", titleKey: "ach_perfect_10", descriptionKey: "ach_perfect_10_desc", condition: .perfectLessons(10)),
        Achievement(id: "words200", icon: "books.vertical.fill", titleKey: "ach_words_200", descriptionKey: "ach_words_200_desc", condition: .words(200)),
        Achievement(id: "quest_week", icon: "calendar.badge.checkmark", titleKey: "ach_quest_week", descriptionKey: "ach_quest_week_desc", condition: .questDays(7)),
        Achievement(id: "checkpoints5", icon: "medal.fill", titleKey: "ach_checkpoints_5", descriptionKey: "ach_checkpoints_5_desc", condition: .checkpoints(5)),
        Achievement(id: "xp2000", icon: "bolt.shield.fill", titleKey: "ach_xp_2000", descriptionKey: "ach_xp_2000_desc", condition: .xp(2000)),
        Achievement(id: "streak30", icon: "crown.fill", titleKey: "ach_streak_30", descriptionKey: "ach_streak_30_desc", condition: .bestStreak(30))
    ]
}

enum AchievementService {
    private static let unlockedKey = "achievements.unlocked"

    // MARK: - Pure calculations (unit tested)

    /// Longest chain of consecutive kept days; frozen days keep the chain without adding to it.
    static func longestStreak(activeDayKeys: Set<String>, frozenDayKeys: Set<String>,
                              calendar: Calendar = .current) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let days = activeDayKeys.union(frozenDayKeys)
            .compactMap { key in formatter.date(from: key).map { (key: key, date: calendar.startOfDay(for: $0)) } }
            .sorted { $0.date < $1.date }

        var best = 0, current = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) != day.date {
                current = 0
            }
            if activeDayKeys.contains(day.key) { current += 1 }
            best = max(best, current)
            previous = day.date
        }
        return best
    }

    static func stats(activities: [DailyActivity], wordsLearned: Int, lessonsCompleted: Int,
                      perfectLessonsFromHistory: Int, checkpointsPassed: Int,
                      calendar: Calendar = .current) -> AchievementStats {
        AchievementStats(
            bestStreak: longestStreak(activeDayKeys: ProgressService.activeDayKeys(from: activities),
                                      frozenDayKeys: ProgressService.frozenDayKeys(from: activities),
                                      calendar: calendar),
            totalXP: ProgressService.totalXP(from: activities),
            wordsLearned: wordsLearned,
            lessonsCompleted: lessonsCompleted,
            // Perfect runs are counted per day since daily quests; lessons finished perfectly before that count once.
            perfectLessons: max(activities.reduce(0) { $0 + $1.perfectLessons }, perfectLessonsFromHistory),
            reviewsDone: activities.reduce(0) { $0 + $1.reviewsDone },
            checkpointsPassed: checkpointsPassed,
            questDaysCompleted: activities.filter { activity in
                guard let kinds = activity.questKinds, !kinds.isEmpty else { return false }
                return Set(activity.claimedQuests ?? []).isSuperset(of: kinds)
            }.count)
    }

    /// Achievements reached by `stats` that aren't unlocked yet.
    static func newlyReached(_ stats: AchievementStats, unlockedIds: Set<String>) -> [Achievement] {
        Achievement.all.filter { !unlockedIds.contains($0.id) && $0.isUnlocked(stats) }
    }

    // MARK: - Persistence

    static func stats(in context: ModelContext) -> AchievementStats {
        let learned = FetchDescriptor<VocabItem>(predicate: #Predicate { $0.srsDue != nil })
        let completed = FetchDescriptor<Lesson>(predicate: #Predicate { $0.isCompleted })
        let passed = FetchDescriptor<CourseUnit>(predicate: #Predicate { $0.checkpointPassed })
        let lessons = (try? context.fetch(completed)) ?? []
        return stats(activities: ProgressService.allActivities(in: context),
                     wordsLearned: (try? context.fetchCount(learned)) ?? 0,
                     lessonsCompleted: lessons.count,
                     perfectLessonsFromHistory: lessons.filter { $0.bestAccuracy >= 0.999 }.count,
                     checkpointsPassed: (try? context.fetchCount(passed)) ?? 0)
    }

    /// Unlock dates by achievement id.
    static func unlockedDates(defaults: UserDefaults = .standard) -> [String: Date] {
        defaults.dictionary(forKey: unlockedKey) as? [String: Date] ?? [:]
    }

    /// Unlocks and returns the achievements reached since the last check.
    @discardableResult
    static func checkNew(in context: ModelContext, defaults: UserDefaults = .standard, now: Date = .now) -> [Achievement] {
        var unlocked = unlockedDates(defaults: defaults)
        let new = newlyReached(stats(in: context), unlockedIds: Set(unlocked.keys))
        guard !new.isEmpty else { return [] }
        new.forEach { unlocked[$0.id] = now }
        defaults.set(unlocked, forKey: unlockedKey)
        return new
    }

    /// Toast for achievements unlocked outside a lesson result (review session, app activation).
    static func toastItem(for achievements: [Achievement]) -> UserMessageItem {
        UserMessageItem(title: "achievement_unlocked".localized(),
                        message: achievements.map { $0.titleKey.localized() }.joined(separator: " · "))
    }

    /// Developer menu ("Reset everything").
    static func resetAll(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: unlockedKey)
    }
}
