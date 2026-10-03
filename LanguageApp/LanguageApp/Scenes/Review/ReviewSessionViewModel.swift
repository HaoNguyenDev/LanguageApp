//
//  ReviewSessionViewModel.swift
//  LanguageApp
//
//  Flashcard session: flip → grade (Again/Hard/Good/Easy) → reschedule with SRS.
//

import Foundation
import Observation

@Observable final class ReviewSessionViewModel {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}

    /// Free users review up to this many cards per session.
    static let freeSessionLimit = 20

    private(set) var queue: [VocabItem]
    private(set) var index = 0
    private(set) var isFlipped = false
    private(set) var reviewedCount = 0
    private(set) var againCount = 0
    private(set) var xpEarned = 0
    private var relearnCounts: [String: Int] = [:]

    private let scheduler: SRSScheduler
    private let now: () -> Date

    init(items: [VocabItem], scheduler: SRSScheduler = SRSScheduler(), now: @escaping () -> Date = { .now }) {
        self.queue = items
        self.scheduler = scheduler
        self.now = now
    }

    /// Picks the cards for a session.
    /// - practice: review learned cards even if not due (soonest due first).
    static func selectItems(from learned: [VocabItem], practice: Bool, limit: Int?, now: Date = .now) -> [VocabItem] {
        let sorted = learned.sorted { ($0.srsDue ?? .distantFuture) < ($1.srsDue ?? .distantFuture) }
        let pool = practice ? sorted : sorted.filter { $0.isDue(at: now) }
        if let limit { return Array(pool.prefix(limit)) }
        return pool
    }

    var current: VocabItem? {
        queue.indices.contains(index) ? queue[index] : nil
    }

    var isFinished: Bool { current == nil }

    var progress: Double {
        guard !queue.isEmpty else { return 1 }
        return Double(index) / Double(queue.count)
    }

    func flip() {
        isFlipped.toggle()
    }

    /// Interval labels for the grade buttons of the current card.
    func previewLabels() -> [ReviewGrade: String] {
        guard let current else { return [:] }
        let preview = scheduler.preview(current.srsState, now: now())
        return preview.mapValues { SRSScheduler.shortLabel(for: $0) }
    }

    func grade(_ grade: ReviewGrade) {
        guard let item = current else { return }
        let date = now()
        item.srsState = scheduler.schedule(item.srsState, grade: grade, now: date)
        item.lastReviewedAt = date
        item.lastReviewGrade = grade.rawValue
        reviewedCount += 1
        xpEarned += 1

        if grade == .again {
            againCount += 1
            // Show a lapsed card again later in this session (max twice).
            let count = relearnCounts[item.remoteId, default: 0]
            if count < 2 {
                relearnCounts[item.remoteId] = count + 1
                let insertAt = min(queue.count, index + 4)
                queue.insert(item, at: insertAt)
            }
        }

        isFlipped = false
        index += 1
    }
}
