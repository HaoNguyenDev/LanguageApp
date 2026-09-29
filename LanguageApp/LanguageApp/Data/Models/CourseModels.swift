//
//  CourseModels.swift
//  LanguageApp
//
//  SwiftData models for course content + per-word SRS state.
//
//  NOTE: Models are kept CloudKit-compatible (no @Attribute(.unique), every property has a
//  default value, relationships are optional) so we can turn on iCloud sync later by
//  switching `ModelConfiguration(cloudKitDatabase: .automatic)`.
//

import Foundation
import SwiftData

@Model
final class Course {
    /// Stable id from content JSON, e.g. "ja".
    var remoteId: String = ""
    var contentVersion: Int = 0
    var order: Int = 0
    var name: LocalizedText = LocalizedText.empty
    var nativeName: String = ""
    var flag: String = ""
    /// BCP-47 locale for AVSpeechSynthesizer, e.g. "ja-JP".
    var speechLocale: String = "en-US"
    /// Label for the `reading` field (Pinyin, Romaji, IPA…).
    var readingLabel: String?

    @Relationship(deleteRule: .cascade, inverse: \CourseUnit.course)
    var units: [CourseUnit]? = []

    init(remoteId: String) {
        self.remoteId = remoteId
    }

    var sortedUnits: [CourseUnit] {
        (units ?? []).sorted { $0.order < $1.order }
    }

    /// Lessons in learning order across all units.
    var orderedLessons: [Lesson] {
        sortedUnits.flatMap(\.sortedLessons)
    }

    var allItems: [VocabItem] {
        orderedLessons.flatMap(\.sortedItems)
    }

    var completedLessonCount: Int {
        orderedLessons.filter(\.isCompleted).count
    }

    var progress: Double {
        let total = orderedLessons.count
        guard total > 0 else { return 0 }
        return Double(completedLessonCount) / Double(total)
    }

    /// A lesson is unlocked if it is the first one or the previous lesson is completed.
    func isUnlocked(_ lesson: Lesson) -> Bool {
        let lessons = orderedLessons
        guard let index = lessons.firstIndex(where: { $0.remoteId == lesson.remoteId }) else { return false }
        return index == 0 || lessons[index - 1].isCompleted
    }

    /// True when this course teaches the app's UI language (e.g. English course + English UI),
    /// so onboarding doesn't offer it.
    func isSameLanguage(asUILanguage uiLanguageCode: String?) -> Bool {
        guard let uiLanguageCode, let code = LanguageCode(rawValue: uiLanguageCode) else { return false }
        return code.courseId == remoteId
    }

    /// First lesson that is unlocked and not completed yet.
    var currentLesson: Lesson? {
        orderedLessons.first { !$0.isCompleted }
    }
}

@Model
final class CourseUnit {
    var remoteId: String = ""
    var order: Int = 0
    var title: LocalizedText = LocalizedText.empty
    var course: Course?

    @Relationship(deleteRule: .cascade, inverse: \Lesson.unit)
    var lessons: [Lesson]? = []

    init(remoteId: String) {
        self.remoteId = remoteId
    }

    var sortedLessons: [Lesson] {
        (lessons ?? []).sorted { $0.order < $1.order }
    }

    var completedCount: Int {
        sortedLessons.filter(\.isCompleted).count
    }
}

@Model
final class Lesson {
    var remoteId: String = ""
    var order: Int = 0
    var title: LocalizedText = LocalizedText.empty
    var icon: String = "star.fill"
    var xpReward: Int = 10

    // Progress
    var isCompleted: Bool = false
    var completedAt: Date?
    var timesCompleted: Int = 0
    var bestAccuracy: Double = 0

    var unit: CourseUnit?

    @Relationship(deleteRule: .cascade, inverse: \VocabItem.lesson)
    var items: [VocabItem]? = []

    init(remoteId: String) {
        self.remoteId = remoteId
    }

    var sortedItems: [VocabItem] {
        (items ?? []).sorted { $0.order < $1.order }
    }

    var course: Course? { unit?.course }
}

@Model
final class VocabItem {
    var remoteId: String = ""
    /// Denormalized for fast queries (`Course.remoteId`).
    var courseId: String = ""
    var order: Int = 0
    var term: String = ""
    var reading: String?
    var meaning: LocalizedText = LocalizedText.empty
    var example: String?
    var exampleMeaning: LocalizedText?

    var lesson: Lesson?

    // MARK: SRS state (nil due == not learned yet)
    var srsDue: Date?
    var srsInterval: Double = 0
    var srsEase: Double = 2.5
    var srsReps: Int = 0
    var srsLapses: Int = 0
    var lastReviewedAt: Date?

    init(remoteId: String, courseId: String) {
        self.remoteId = remoteId
        self.courseId = courseId
    }

    var isLearned: Bool { srsDue != nil }

    func isDue(at date: Date = .now) -> Bool {
        guard let srsDue else { return false }
        return srsDue <= date
    }

    var srsState: SRSState {
        get {
            SRSState(reps: srsReps, interval: srsInterval, ease: srsEase, lapses: srsLapses, due: srsDue)
        }
        set {
            srsReps = newValue.reps
            srsInterval = newValue.interval
            srsEase = newValue.ease
            srsLapses = newValue.lapses
            srsDue = newValue.due
        }
    }

    var strength: WordStrength { WordStrength(interval: srsInterval, isLearned: isLearned) }

    func resetProgress() {
        srsState = SRSState()
        lastReviewedAt = nil
    }
}

/// Coarse memory strength shown in the word list.
enum WordStrength: Int {
    case new = 0, weak, medium, strong

    init(interval: Double, isLearned: Bool) {
        guard isLearned else { self = .new; return }
        switch interval {
        case ..<3: self = .weak
        case ..<14: self = .medium
        default: self = .strong
        }
    }

    var titleKey: String {
        switch self {
        case .new: return "strength_new"
        case .weak: return "strength_weak"
        case .medium: return "strength_medium"
        case .strong: return "strength_strong"
        }
    }

    var bars: Int { rawValue }
}

/// One row per calendar day with activity – used for streaks, daily goal & weekly chart.
@Model
final class DailyActivity {
    /// "yyyy-MM-dd" in the user's calendar.
    var dayKey: String = ""
    var date: Date = Date.now
    var xp: Int = 0
    var lessonsCompleted: Int = 0
    var reviewsDone: Int = 0

    init(dayKey: String, date: Date) {
        self.dayKey = dayKey
        self.date = date
    }
}
