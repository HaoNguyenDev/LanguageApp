//
//  UnitCheckpointService.swift
//  LanguageApp
//
//  Unit checkpoint: a short test on the words of a unit, unlocked once every lesson of the unit
//  is completed. Passing it (≥ 80 % correct) unlocks the next unit.
//

import Foundation
import SwiftData

struct CheckpointOutcome: Hashable {
    let passed: Bool
    /// True the first time this unit's checkpoint is passed (the next unit opens).
    let unlockedNextUnit: Bool
    let requiredAccuracy: Double
}

enum UnitCheckpointService {
    static let passAccuracy = 0.8
    /// Words tested per checkpoint.
    static let wordCount = 10
    /// XP for passing (+5 for a perfect run, like a lesson). A failed attempt gives no XP.
    static let xpReward = 20

    // MARK: - Pure calculations (unit tested)

    static func isPassing(accuracy: Double) -> Bool {
        accuracy + 0.0001 >= passAccuracy
    }

    /// Half of the words are the learner's weakest of the unit, the rest are picked at random,
    /// so every checkpoint mixes known trouble spots with the rest of the unit.
    static func pickWords(_ words: [PracticeService.Candidate],
                          count: Int = wordCount,
                          using rng: inout some RandomNumberGenerator) -> [String] {
        guard words.count > count else { return words.shuffled(using: &rng).map(\.id) }
        let weak = words
            .filter { PracticeService.weakness($0) > 0 }
            .sorted { PracticeService.weakness($0) > PracticeService.weakness($1) }
            .prefix(count / 2)
            .map(\.id)
        let weakIds = Set(weak)
        let rest = words.filter { !weakIds.contains($0.id) }.shuffled(using: &rng).prefix(count - weak.count).map(\.id)
        return (weak + rest).shuffled(using: &rng)
    }

    // MARK: - Persistence

    /// Records an attempt: mistakes always, XP + "passed" only when the learner passes.
    @discardableResult
    static func complete(unit: CourseUnit,
                         items: [VocabItem],
                         accuracy: Double,
                         dailyGoalXP: Int,
                         mistakes: [String: Int] = [:],
                         in context: ModelContext,
                         now: Date = .now) -> LessonResult {
        let xpBefore = ProgressService.xp(on: now, from: ProgressService.allActivities(in: context))
        let passed = isPassing(accuracy: accuracy)
        let isPerfect = accuracy >= 0.999
        let unlockedNextUnit = passed && !unit.checkpointPassed

        PracticeService.recordMistakes(mistakes, for: items, forgiveCorrect: false, now: now)
        unit.checkpointBestAccuracy = max(unit.checkpointBestAccuracy, accuracy)
        var xp = 0
        if passed {
            if !unit.checkpointPassed {
                unit.checkpointPassed = true
                unit.checkpointPassedAt = now
            }
            xp = ProgressService.lessonXP(base: xpReward, accuracy: accuracy)
            ProgressService.record(xp: xp, lessons: 1, perfect: isPerfect ? 1 : 0, in: context, now: now)
        }
        try? context.save()
        let quests = passed ? DailyQuestService.claimCompleted(in: context, dailyGoalXP: dailyGoalXP, now: now) : []

        let activities = ProgressService.allActivities(in: context)
        let xpAfter = ProgressService.xp(on: now, from: activities)
        return LessonResult(xpEarned: xp,
                            accuracy: accuracy,
                            newWords: 0,
                            streak: ProgressService.streak(from: activities, today: now),
                            isPerfect: isPerfect,
                            reachedDailyGoal: xpBefore < dailyGoalXP && xpAfter >= dailyGoalXP,
                            completedQuests: quests,
                            checkpoint: CheckpointOutcome(passed: passed,
                                                          unlockedNextUnit: unlockedNextUnit,
                                                          requiredAccuracy: passAccuracy))
    }
}
