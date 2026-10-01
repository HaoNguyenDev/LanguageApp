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
}
