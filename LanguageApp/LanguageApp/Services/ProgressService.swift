//
//  ProgressService.swift
//  LanguageApp
//
//  XP, streak, daily goal and lesson completion.
//  Streak freezes are applied in `StreakFreezeService`.
//

import Foundation
import SwiftData

enum ProgressService {

    // MARK: - Day keys

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Pure calculations (unit tested)

    /// Consecutive active days ending today (or yesterday, if today has no activity yet).
    /// Frozen days (covered by a streak freeze) keep the chain alive but don't add to it.
    static func streak(activeDayKeys: Set<String>,
                       frozenDayKeys: Set<String> = [],
                       today: Date = .now,
                       calendar: Calendar = .current) -> Int {
        let keptDayKeys = activeDayKeys.union(frozenDayKeys)
        var day = calendar.startOfDay(for: today)
        if !keptDayKeys.contains(dayKey(for: day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  keptDayKeys.contains(dayKey(for: yesterday, calendar: calendar)) else {
                return 0
            }
            day = yesterday
        }
        var count = 0
        while true {
            let key = dayKey(for: day, calendar: calendar)
            guard keptDayKeys.contains(key) else { break }
            if activeDayKeys.contains(key) { count += 1 }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func streak(from activities: [DailyActivity], today: Date = .now, calendar: Calendar = .current) -> Int {
        streak(activeDayKeys: activeDayKeys(from: activities),
               frozenDayKeys: frozenDayKeys(from: activities),
               today: today,
               calendar: calendar)
    }

    /// Days with XP.
    static func activeDayKeys(from activities: [DailyActivity]) -> Set<String> {
        Set(activities.filter { $0.xp > 0 }.map(\.dayKey))
    }

    /// Missed days covered by a streak freeze.
    static func frozenDayKeys(from activities: [DailyActivity]) -> Set<String> {
        Set(activities.filter(\.streakFreezeUsed).map(\.dayKey))
    }

    static func xp(on date: Date, from activities: [DailyActivity], calendar: Calendar = .current) -> Int {
        let key = dayKey(for: date, calendar: calendar)
        return activities.filter { $0.dayKey == key }.reduce(0) { $0 + $1.xp }
    }

    static func totalXP(from activities: [DailyActivity]) -> Int {
        activities.reduce(0) { $0 + $1.xp }
    }

    /// XP of the last `days` days, oldest first (for the weekly chart).
    static func xpHistory(days: Int, from activities: [DailyActivity], today: Date = .now, calendar: Calendar = .current) -> [(date: Date, xp: Int)] {
        let start = calendar.startOfDay(for: today)
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            let value = xp(on: date, from: activities, calendar: calendar)
            return (date: date, xp: value)
        }
    }

    /// Lesson XP: base reward + 5 bonus for a perfect run.
    static func lessonXP(base: Int, accuracy: Double) -> Int {
        base + (accuracy >= 0.999 ? 5 : 0)
    }

    // MARK: - Persistence

    static func record(xp: Int, lessons: Int = 0, reviews: Int = 0, in context: ModelContext, now: Date = .now) {
        let key = dayKey(for: now)
        let descriptor = FetchDescriptor<DailyActivity>(predicate: #Predicate { $0.dayKey == key })
        let activity: DailyActivity
        if let existing = try? context.fetch(descriptor).first {
            activity = existing
        } else {
            activity = DailyActivity(dayKey: key, date: Calendar.current.startOfDay(for: now))
            context.insert(activity)
        }
        activity.xp += xp
        activity.lessonsCompleted += lessons
        activity.reviewsDone += reviews
    }

    static func allActivities(in context: ModelContext) -> [DailyActivity] {
        (try? context.fetch(FetchDescriptor<DailyActivity>())) ?? []
    }
}

struct LessonResult: Hashable {
    let xpEarned: Int
    let accuracy: Double
    let newWords: Int
    let streak: Int
    let isPerfect: Bool
    let reachedDailyGoal: Bool
}

enum LessonCompletionService {
    /// Marks the lesson complete, introduces its words into SRS and records XP.
    @discardableResult
    static func complete(lesson: Lesson,
                         accuracy: Double,
                         dailyGoalXP: Int,
                         mistakes: [String: Int] = [:],
                         in context: ModelContext,
                         scheduler: SRSScheduler = SRSScheduler(),
                         now: Date = .now) -> LessonResult {
        let xpBefore = ProgressService.xp(on: now, from: ProgressService.allActivities(in: context))
        let xp = ProgressService.lessonXP(base: lesson.xpReward, accuracy: accuracy)

        lesson.isCompleted = true
        lesson.completedAt = now
        lesson.timesCompleted += 1
        lesson.bestAccuracy = max(lesson.bestAccuracy, accuracy)

        var newWords = 0
        for item in lesson.sortedItems where !item.isLearned {
            item.srsState = scheduler.introduce(now: now)
            item.lastReviewedAt = now
            newWords += 1
        }

        PracticeService.recordMistakes(mistakes, for: lesson.sortedItems, forgiveCorrect: false, now: now)
        ProgressService.record(xp: xp, lessons: 1, in: context, now: now)
        try? context.save()

        let activities = ProgressService.allActivities(in: context)
        let xpAfter = ProgressService.xp(on: now, from: activities)
        return LessonResult(xpEarned: xp,
                            accuracy: accuracy,
                            newWords: newWords,
                            streak: ProgressService.streak(from: activities, today: now),
                            isPerfect: accuracy >= 0.999,
                            reachedDailyGoal: xpBefore < dailyGoalXP && xpAfter >= dailyGoalXP)
    }

    /// Resets lessons + SRS of a course (keeps XP history).
    static func resetProgress(of course: Course, in context: ModelContext) {
        for lesson in course.orderedLessons {
            lesson.isCompleted = false
            lesson.completedAt = nil
            lesson.timesCompleted = 0
            lesson.bestAccuracy = 0
            lesson.sortedItems.forEach { $0.resetProgress() }
        }
        try? context.save()
    }
}
