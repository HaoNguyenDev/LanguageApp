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
    /// The first lesson of a unit also needs the previous unit's checkpoint passed
    /// (lessons already completed stay unlocked, so earlier progress is never locked away).
    func isUnlocked(_ lesson: Lesson) -> Bool {
        if DebugSettings.shared.unlocksAllLessons { return true }
        let lessons = orderedLessons
        guard let index = lessons.firstIndex(where: { $0.remoteId == lesson.remoteId }) else { return false }
        if index == 0 || lesson.isCompleted { return true }
        guard lessons[index - 1].isCompleted else { return false }
        return !isWaitingForCheckpoint(lesson)
    }

    /// True for the first lesson of a unit whose previous unit's checkpoint isn't passed yet.
    func isWaitingForCheckpoint(_ lesson: Lesson) -> Bool {
        guard !lesson.isCompleted,
              let unit = lesson.unit,
              unit.sortedLessons.first?.remoteId == lesson.remoteId,
              let unitIndex = sortedUnits.firstIndex(where: { $0.remoteId == unit.remoteId }),
              unitIndex > 0 else { return false }
        return !sortedUnits[unitIndex - 1].checkpointPassed
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

    // MARK: Checkpoint (test at the end of the unit)
    var checkpointPassed: Bool = false
    var checkpointPassedAt: Date?
    var checkpointBestAccuracy: Double = 0

    var allLessonsCompleted: Bool {
        let lessons = sortedLessons
        return !lessons.isEmpty && lessons.allSatisfy(\.isCompleted)
    }

    /// The checkpoint opens once every lesson of the unit is completed.
    var isCheckpointUnlocked: Bool {
        DebugSettings.shared.unlocksAllLessons || allLessonsCompleted
    }

    var allItems: [VocabItem] {
        sortedLessons.flatMap(\.sortedItems)
    }
}

@Model
final class Lesson {
    var remoteId: String = ""
    var order: Int = 0
    var title: LocalizedText = LocalizedText.empty
    var icon: String = "star.fill"
    var xpReward: Int = 10
    /// Rule of the language explained on a card before the first question (e.g. how numbers are built).
    var tip: LocalizedText?

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
    /// `example` split into chunks (words, or phrases for Chinese / Japanese) for the sentence builder.
    var exampleTokens: [String]?
    var exampleMeaning: LocalizedText?

    var lesson: Lesson?

    // MARK: SRS state (nil due == not learned yet)
    var srsDue: Date?
    var srsInterval: Double = 0
    var srsEase: Double = 2.5
    var srsReps: Int = 0
    var srsLapses: Int = 0
    var lastReviewedAt: Date?

    // MARK: Mistakes in lessons / practice (drives "Practice weak words")
    var mistakeCount: Int = 0
    var lastMistakeAt: Date?

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
        mistakeCount = 0
        lastMistakeAt = nil
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

/// One row per calendar day with activity (or a streak freeze) – used for streaks, daily goal & weekly chart.
@Model
final class DailyActivity {
    /// "yyyy-MM-dd" in the user's calendar.
    var dayKey: String = ""
    var date: Date = Date.now
    var xp: Int = 0
    var lessonsCompleted: Int = 0
    var reviewsDone: Int = 0
    /// A missed day covered by a streak freeze: keeps the streak alive without adding to it.
    var streakFreezeUsed: Bool = false
    /// Lessons (or practice sessions) finished without a mistake.
    var perfectLessons: Int = 0
    /// Daily quests picked for this day (`DailyQuest.Kind` raw values), fixed once generated.
    var questKinds: [String]?
    /// Daily quests whose XP reward was already given.
    var claimedQuests: [String]?

    init(dayKey: String, date: Date) {
        self.dayKey = dayKey
        self.date = date
    }
}
