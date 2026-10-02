//
//  DailyQuestService.swift
//  LanguageApp
//
//  Three daily quests ("Earn 20 XP", "Complete 2 lessons", …) with XP rewards.
//  The quests of a day are picked once (stored in `DailyActivity.questKinds`) and
//  progress is read from that day's activity counters. Rewards are given automatically
//  as soon as a quest is complete (`claimCompleted`).
//

import Foundation
import SwiftData

struct DailyQuest: Hashable, Identifiable {
    enum Kind: String, CaseIterable {
        case earnXP = "earn_xp"
        case completeLessons = "complete_lessons"
        case reviewCards = "review_cards"
        case perfectLesson = "perfect_lesson"
    }

    let kind: Kind
    let target: Int
    let rewardXP: Int

    var id: String { kind.rawValue }

    var icon: String {
        switch kind {
        case .earnXP: return "bolt.fill"
        case .completeLessons: return "book.fill"
        case .reviewCards: return "rectangle.stack.fill"
        case .perfectLesson: return "star.fill"
        }
    }

    var title: String {
        switch kind {
        case .earnXP: return "quest_earn_xp".localizedFormat(target)
        case .completeLessons: return "quest_complete_lessons".localizedFormat(target)
        case .reviewCards: return "quest_review_cards".localizedFormat(target)
        case .perfectLesson: return "quest_perfect_lesson".localized()
        }
    }
}

enum DailyQuestService {
    static let questsPerDay = 3
    static let lessonsTarget = 2
    static let reviewCardsTarget = 15

    // MARK: - Pure calculations (unit tested)

    /// Quest kinds for a day: always "earn XP" (the daily goal) + two others picked by the day.
    /// Without learned words there's nothing to review, so the review quest isn't offered.
    /// - Parameter shift: picks another set for the same day (developer menu "Next quest set").
    static func plan(dayKey: String, hasLearnedWords: Bool, shift: Int = 0) -> [DailyQuest.Kind] {
        let candidates = candidates(hasLearnedWords: hasLearnedWords)
        let start = Int((stableHash(dayKey) &+ UInt64(max(shift, 0))) % UInt64(candidates.count))
        let rotated = Array(candidates[start...] + candidates[..<start])
        return [.earnXP] + rotated.prefix(questsPerDay - 1)
    }

    /// Quests that can join "earn XP"; nothing to review without learned words.
    static func candidates(hasLearnedWords: Bool) -> [DailyQuest.Kind] {
        hasLearnedWords ? [.completeLessons, .reviewCards, .perfectLesson] : [.completeLessons, .perfectLesson]
    }

    static func quest(_ kind: DailyQuest.Kind, dailyGoalXP: Int) -> DailyQuest {
        switch kind {
        case .earnXP: return DailyQuest(kind: kind, target: max(dailyGoalXP, 1), rewardXP: 10)
        case .completeLessons: return DailyQuest(kind: kind, target: lessonsTarget, rewardXP: 15)
        case .reviewCards: return DailyQuest(kind: kind, target: reviewCardsTarget, rewardXP: 10)
        case .perfectLesson: return DailyQuest(kind: kind, target: 1, rewardXP: 15)
        }
    }

    /// Quests of a day; falls back to a plan for a day whose quests aren't picked yet.
    static func quests(for activity: DailyActivity?, dayKey: String, dailyGoalXP: Int) -> [DailyQuest] {
        let kinds = activity?.questKinds?.compactMap(DailyQuest.Kind.init(rawValue:))
            ?? plan(dayKey: dayKey, hasLearnedWords: true)
        return kinds.map { quest($0, dailyGoalXP: dailyGoalXP) }
    }

    /// Progress towards the target (may exceed it).
    static func progress(of quest: DailyQuest, in activity: DailyActivity?) -> Int {
        guard let activity else { return 0 }
        switch quest.kind {
        case .earnXP: return activity.xp
        case .completeLessons: return activity.lessonsCompleted
        case .reviewCards: return activity.reviewsDone
        case .perfectLesson: return activity.perfectLessons
        }
    }

    static func isComplete(_ quest: DailyQuest, in activity: DailyActivity?) -> Bool {
        progress(of: quest, in: activity) >= quest.target
    }

    /// FNV-1a – `String.hashValue` changes between launches, so it can't pick the quests of a day.
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    // MARK: - Persistence

    /// Picks today's quests once (called when the app becomes active and before claiming).
    @discardableResult
    static func ensureTodayQuests(in context: ModelContext, now: Date = .now) -> DailyActivity {
        let activity = ProgressService.activity(on: now, in: context)
        if activity.questKinds == nil {
            let learned = FetchDescriptor<VocabItem>(predicate: #Predicate { $0.srsDue != nil })
            let hasLearnedWords = ((try? context.fetchCount(learned)) ?? 0) > 0
            activity.questKinds = plan(dayKey: activity.dayKey, hasLearnedWords: hasLearnedWords).map(\.rawValue)
            try? context.save()
        }
        return activity
    }

    /// Gives the XP reward of every quest completed today and not rewarded yet.
    /// A reward can complete the "earn XP" quest, so this repeats until nothing changes.
    /// - Returns: the quests completed now.
    @discardableResult
    static func claimCompleted(in context: ModelContext, dailyGoalXP: Int, now: Date = .now) -> [DailyQuest] {
        let activity = ensureTodayQuests(in: context, now: now)
        let quests = Self.quests(for: activity, dayKey: activity.dayKey, dailyGoalXP: dailyGoalXP)
        var claimed = activity.claimedQuests ?? []
        var newlyCompleted: [DailyQuest] = []
        var changed = true
        while changed {
            changed = false
            for quest in quests where !claimed.contains(quest.id) && isComplete(quest, in: activity) {
                claimed.append(quest.id)
                activity.xp += quest.rewardXP
                newlyCompleted.append(quest)
                changed = true
            }
        }
        guard !newlyCompleted.isEmpty else { return [] }
        activity.claimedQuests = claimed
        try? context.save()
        return newlyCompleted
    }

    /// Toast shown when quests are completed outside a lesson (review session, app activation).
    static func toastItem(for quests: [DailyQuest]) -> UserMessageItem {
        let reward = quests.reduce(0) { $0 + $1.rewardXP }
        let names = quests.map(\.title).joined(separator: " · ")
        return UserMessageItem(title: "quest_complete_title".localized(),
                               message: "\(names)\n" + "xp_earned".localizedFormat(reward))
    }
}
