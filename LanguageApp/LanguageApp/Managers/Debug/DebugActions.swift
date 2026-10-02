//
//  DebugActions.swift
//  LanguageApp
//
//  One-shot data changes for testing, triggered from the developer menu (Debug builds only).
//

import Foundation
import SwiftData

enum DebugActions {
    /// Marks lessons as completed and puts their words into SRS – without XP, like a finished lesson.
    static func complete(_ lessons: [Lesson], in context: ModelContext, now: Date = .now) {
        let scheduler = SRSScheduler()
        for lesson in lessons where !lesson.isCompleted {
            lesson.isCompleted = true
            lesson.completedAt = now
            lesson.timesCompleted = max(1, lesson.timesCompleted)
            lesson.bestAccuracy = max(lesson.bestAccuracy, 1)
            for item in lesson.sortedItems where !item.isLearned {
                item.srsState = scheduler.introduce(now: now)
                item.lastReviewedAt = now
            }
        }
        try? context.save()
    }

    /// Lessons of the unit the learner is currently in (first unit with an unfinished lesson).
    static func currentUnitLessons(of course: Course) -> [Lesson] {
        course.sortedUnits.first { unit in unit.sortedLessons.contains { !$0.isCompleted } }?.sortedLessons ?? []
    }

    /// Every learned word of the course becomes due now (to test the review session).
    @discardableResult
    static func makeAllDue(in course: Course, context: ModelContext, now: Date = .now) -> Int {
        let learned = course.allItems.filter(\.isLearned)
        learned.forEach { $0.srsDue = now.addingTimeInterval(-60) }
        try? context.save()
        return learned.count
    }

    /// Gives random learned words a few mistakes (to test "Practice weak words").
    @discardableResult
    static func markRandomWordsWeak(in course: Course, count: Int = 8, context: ModelContext, now: Date = .now) -> Int {
        let picked = course.allItems.filter(\.isLearned).shuffled().prefix(count)
        for item in picked {
            item.mistakeCount += 3
            item.lastMistakeAt = now
        }
        try? context.save()
        return picked.count
    }

    static func addXP(_ xp: Int, in context: ModelContext, now: Date = .now) {
        ProgressService.record(xp: xp, in: context, now: now)
        try? context.save()
    }

    /// Activity on each of the last `days` days, so the streak becomes `days`.
    static func buildStreak(days: Int, in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            ProgressService.record(xp: 10, lessons: 1, in: context, now: date)
        }
        try? context.save()
    }

    /// A 7-day streak that ended the day before yesterday: yesterday is missed (and today has no activity),
    /// so a streak freeze can save it.
    static func buildStreakMissingYesterday(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let recentKeys = [0, 1].compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now).map { ProgressService.dayKey(for: $0, calendar: calendar) }
        }
        ProgressService.allActivities(in: context)
            .filter { recentKeys.contains($0.dayKey) }
            .forEach { context.delete($0) }
        try? context.save()
        guard let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: now) else { return }
        buildStreak(days: 7, in: context, now: dayBeforeYesterday, calendar: calendar)
    }

    /// Today starts from zero: XP, lessons, reviews and perfect lessons of today are cleared,
    /// today's quests and rewards too, then quests are picked again. Earlier days are kept,
    /// so the streak stays if yesterday counted.
    static func startTodayOver(in context: ModelContext, now: Date = .now) {
        let activity = ProgressService.activity(on: now, in: context)
        activity.xp = 0
        activity.lessonsCompleted = 0
        activity.reviewsDone = 0
        activity.perfectLessons = 0
        activity.questKinds = nil
        activity.claimedQuests = nil
        try? context.save()
        DailyQuestService.ensureTodayQuests(in: context, now: now)
    }

    /// Switches today to the next quest set (rewards already given are kept, so nothing is paid twice).
    /// - Returns: the new quest kinds.
    @discardableResult
    static func nextQuestSet(in context: ModelContext, now: Date = .now) -> [DailyQuest.Kind] {
        let activity = DailyQuestService.ensureTodayQuests(in: context, now: now)
        let current = activity.questKinds?.compactMap(DailyQuest.Kind.init(rawValue:)) ?? []
        let hasLearnedWords = current.contains(.reviewCards)
            || ((try? context.fetchCount(FetchDescriptor<VocabItem>(predicate: #Predicate { $0.srsDue != nil }))) ?? 0) > 0
        let count = DailyQuestService.candidates(hasLearnedWords: hasLearnedWords).count
        let shift = (0..<count).first {
            DailyQuestService.plan(dayKey: activity.dayKey, hasLearnedWords: hasLearnedWords, shift: $0) == current
        } ?? -1
        let next = DailyQuestService.plan(dayKey: activity.dayKey, hasLearnedWords: hasLearnedWords, shift: shift + 1)
        activity.questKinds = next.map(\.rawValue)
        try? context.save()
        return next
    }

    /// Lessons and SRS of every course back to "not started" (XP, streak and quests are kept).
    static func resetAllCourses(in context: ModelContext) {
        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        courses.forEach { LessonCompletionService.resetProgress(of: $0, in: context) }
    }

    /// Like a fresh install (except settings and onboarding): every course reset,
    /// all daily activity (XP, streak, freezes used, quests) deleted.
    /// Call `GamificationManager.debugResetAll()` too for hearts and streak freezes.
    static func resetEverything(in context: ModelContext) {
        resetAllCourses(in: context)
        ProgressService.allActivities(in: context).forEach { context.delete($0) }
        try? context.save()
    }
}
