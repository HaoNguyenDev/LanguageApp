//
//  SRSScheduler.swift
//  LanguageApp
//
//  Spaced-repetition scheduler (SM-2 variant, similar to Anki's 4-button grading).
//

import Foundation

enum ReviewGrade: Int, CaseIterable, Identifiable {
    case again = 0
    case hard
    case good
    case easy

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .again: return "grade_again"
        case .hard: return "grade_hard"
        case .good: return "grade_good"
        case .easy: return "grade_easy"
        }
    }
}

struct SRSState: Equatable {
    /// Consecutive successful reviews.
    var reps: Int = 0
    /// Current interval in days (0 = relearning, due within minutes).
    var interval: Double = 0
    var ease: Double = 2.5
    var lapses: Int = 0
    var due: Date?
}

struct SRSScheduler {
    var minimumEase: Double = 1.3
    var maximumIntervalDays: Double = 365
    /// Delay before a lapsed card is shown again.
    var relearnDelay: TimeInterval = 10 * 60

    private static let day: TimeInterval = 24 * 60 * 60

    /// State for a word the learner has just met in a lesson: first review tomorrow.
    func introduce(now: Date = .now) -> SRSState {
        SRSState(reps: 1, interval: 1, ease: 2.5, lapses: 0, due: now.addingTimeInterval(Self.day))
    }

    func schedule(_ state: SRSState, grade: ReviewGrade, now: Date = .now) -> SRSState {
        var next = state

        switch grade {
        case .again:
            next.reps = 0
            next.lapses += 1
            next.ease = max(minimumEase, state.ease - 0.2)
            next.interval = 0
            next.due = now.addingTimeInterval(relearnDelay)
            return next

        case .hard:
            next.ease = max(minimumEase, state.ease - 0.15)
            next.interval = state.reps == 0 ? 1 : max(1, state.interval * 1.2)

        case .good:
            switch state.reps {
            case 0: next.interval = 1
            case 1: next.interval = max(3, state.interval * state.ease)
            default: next.interval = max(state.interval + 1, state.interval * state.ease)
            }

        case .easy:
            next.ease = state.ease + 0.15
            switch state.reps {
            case 0: next.interval = 4
            default: next.interval = max(state.interval + 2, state.interval * state.ease * 1.3)
            }
        }

        next.reps += 1
        next.interval = min(maximumIntervalDays, (next.interval * 10).rounded() / 10)
        next.due = now.addingTimeInterval(next.interval * Self.day)
        return next
    }

    /// Next due date for each grade – used to label the grade buttons.
    func preview(_ state: SRSState, now: Date = .now) -> [ReviewGrade: TimeInterval] {
        var result: [ReviewGrade: TimeInterval] = [:]
        for grade in ReviewGrade.allCases {
            let due = schedule(state, grade: grade, now: now).due ?? now
            result[grade] = due.timeIntervalSince(now)
        }
        return result
    }

    /// Short human label: "10m", "1d", "3d", "2mo", "1y".
    static func shortLabel(for interval: TimeInterval) -> String {
        let minutes = interval / 60
        if minutes < 60 { return "\(max(1, Int(minutes.rounded())))m" }
        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours.rounded()))h" }
        let days = hours / 24
        if days < 30 { return "\(Int(days.rounded()))d" }
        if days < 365 { return "\(Int((days / 30).rounded()))mo" }
        return "\(Int((days / 365).rounded()))y"
    }
}
