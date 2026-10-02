//
//  PracticeService.swift
//  LanguageApp
//
//  "Practice weak words": picks the learner's weakest words and records the outcome.
//  Weakness combines mistakes in lessons/practice with the SRS state (lapses, low ease, short interval).
//

import Foundation
import SwiftData

enum PracticeService {
    /// Words per practice session.
    static let sessionSize = 8
    /// Fewer learned words than this → no practice (match pairs and distractors need a few words).
    static let minimumWords = 4

    /// What the selection needs to know about a word (keeps the logic testable without SwiftData).
    struct Candidate: Equatable {
        let id: String
        var mistakes: Int = 0
        var lapses: Int = 0
        var ease: Double = 2.5
        var interval: Double = 0
    }

    /// 0 = solid. Higher = practice first.
    static func weakness(_ word: Candidate) -> Double {
        Double(word.mistakes) * 2
            + Double(word.lapses) * 3
            + max(0, 2.5 - word.ease) * 4
            + (word.interval < 3 ? 1 : 0)   // same threshold as `WordStrength.weak`
    }

    static func weakCount(_ words: [Candidate]) -> Int {
        words.filter { weakness($0) > 0 }.count
    }

    /// Weakest words first; when there are too few weak words the session is topped up with the
    /// words that have the shortest interval. Empty when fewer than `minimumWords` are learned.
    static func pickWords(_ words: [Candidate], limit: Int = sessionSize) -> [String] {
        guard words.count >= minimumWords else { return [] }
        let sorted = words.sorted { a, b in
            let wa = weakness(a), wb = weakness(b)
            if wa != wb { return wa > wb }
            if a.interval != b.interval { return a.interval < b.interval }
            return a.id < b.id
        }
        return sorted.prefix(limit).map(\.id)
    }

    /// Adds lesson/practice mistakes to the words. With `forgiveCorrect`, a practised word answered
    /// without mistakes loses one mistake, so it gradually leaves the weak list.
    static func recordMistakes(_ mistakes: [String: Int], for items: [VocabItem],
                               forgiveCorrect: Bool, now: Date = .now) {
        for item in items {
            let count = mistakes[item.remoteId] ?? 0
            if count > 0 {
                item.mistakeCount += count
                item.lastMistakeAt = now
            } else if forgiveCorrect {
                item.mistakeCount = max(0, item.mistakeCount - 1)
            }
        }
    }

    /// Finishes a practice session: updates mistakes and records XP (no lesson, no new words).
    @discardableResult
    static func complete(items: [VocabItem],
                         mistakes: [String: Int],
                         accuracy: Double,
                         dailyGoalXP: Int,
                         in context: ModelContext,
                         now: Date = .now) -> LessonResult {
        let xpBefore = ProgressService.xp(on: now, from: ProgressService.allActivities(in: context))
        let xp = ProgressService.lessonXP(base: 10, accuracy: accuracy)

        let isPerfect = accuracy >= 0.999
        recordMistakes(mistakes, for: items, forgiveCorrect: true, now: now)
        ProgressService.record(xp: xp, perfect: isPerfect ? 1 : 0, in: context, now: now)
        try? context.save()
        let quests = DailyQuestService.claimCompleted(in: context, dailyGoalXP: dailyGoalXP, now: now)

        let activities = ProgressService.allActivities(in: context)
        let xpAfter = ProgressService.xp(on: now, from: activities)
        return LessonResult(xpEarned: xp,
                            accuracy: accuracy,
                            newWords: 0,
                            streak: ProgressService.streak(from: activities, today: now),
                            isPerfect: isPerfect,
                            reachedDailyGoal: xpBefore < dailyGoalXP && xpAfter >= dailyGoalXP,
                            completedQuests: quests)
    }
}

extension VocabItem {
    var practiceCandidate: PracticeService.Candidate {
        PracticeService.Candidate(id: remoteId, mistakes: mistakeCount, lapses: srsLapses,
                                  ease: srsEase, interval: srsInterval)
    }
}
