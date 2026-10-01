//
//  LessonSessionViewModel.swift
//  LanguageApp
//
//  State machine of a lesson: answer → check → feedback → next … → finished.
//  Wrong answers are re-queued once at the end (like Duolingo).
//

import Foundation
import Observation

@Observable final class LessonSessionViewModel {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}

    enum Phase: Equatable {
        case answering
        case feedback(isCorrect: Bool)
        case outOfHearts
        case finished
    }

    let lessonTitle: String
    private(set) var exercises: [Exercise]
    private(set) var currentIndex = 0
    private(set) var phase: Phase = .answering
    var selectedOptionId: String?
    /// Text typed for typing exercises.
    var typedAnswer = ""
    /// The last typed answer was accepted with a spelling slip (missing accent / one typo).
    private(set) var lastAnswerWasAlmost = false

    private(set) var gradedCount = 0
    private(set) var correctCount = 0
    private var requeuedIds = Set<String>()

    /// Called on each mistake (hearts); return false when no hearts are left.
    @ObservationIgnored var onMistake: (() -> Bool)?

    init(lessonTitle: String, exercises: [Exercise]) {
        self.lessonTitle = lessonTitle
        self.exercises = exercises
        if exercises.isEmpty { phase = .finished }
    }

    var current: Exercise? {
        exercises.indices.contains(currentIndex) ? exercises[currentIndex] : nil
    }

    var progress: Double {
        guard !exercises.isEmpty else { return 1 }
        let done = Double(currentIndex) + (isShowingFeedback ? 1 : 0)
        return done / Double(exercises.count)
    }

    var isShowingFeedback: Bool {
        if case .feedback = phase { return true }
        return false
    }

    var accuracy: Double {
        guard gradedCount > 0 else { return 1 }
        return Double(correctCount) / Double(gradedCount)
    }

    var canCheck: Bool {
        guard phase == .answering, let current else { return false }
        if current.isTyping {
            return !typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedOptionId != nil
    }

    // MARK: - Actions

    func select(_ optionId: String) {
        guard phase == .answering else { return }
        selectedOptionId = optionId
    }

    /// Grades the selected option of a choice exercise, or the typed answer of a typing exercise.
    @discardableResult
    func check() -> Bool {
        guard canCheck, let current else { return false }
        let isCorrect: Bool
        if current.isTyping, let item = current.studyItem {
            let result = AnswerMatcher.grade(typedAnswer, for: item)
            lastAnswerWasAlmost = result == .almost
            isCorrect = result != .wrong
        } else if let correctId = current.correctOptionId {
            isCorrect = selectedOptionId == correctId
        } else {
            return false
        }
        grade(current, isCorrect: isCorrect)
        return isCorrect
    }

    /// Match-pairs exercise reports its own result.
    func completeMatch(mistakes: Int) {
        guard phase == .answering, current != nil else { return }
        gradedCount += 1
        if mistakes == 0 { correctCount += 1 }
        // Mistakes inside matching don't cost hearts – they are corrected on the spot.
        phase = .feedback(isCorrect: mistakes == 0)
    }

    /// Continue after an intro card or the feedback banner.
    func next() {
        if phase == .outOfHearts || phase == .finished { return }
        selectedOptionId = nil
        typedAnswer = ""
        lastAnswerWasAlmost = false
        if currentIndex + 1 < exercises.count {
            currentIndex += 1
            phase = .answering
        } else {
            currentIndex = exercises.count
            phase = .finished
        }
    }

    /// Lets the user continue after refilling hearts (e.g. purchased premium).
    func resumeAfterRefill() {
        guard phase == .outOfHearts else { return }
        phase = .feedback(isCorrect: false)
    }

    private func grade(_ exercise: Exercise, isCorrect: Bool) {
        gradedCount += 1
        if isCorrect {
            correctCount += 1
            phase = .feedback(isCorrect: true)
            return
        }

        if !requeuedIds.contains(exercise.id) {
            requeuedIds.insert(exercise.id)
            exercises.append(exercise)
        }
        let hasHeartsLeft = onMistake?() ?? true
        phase = hasHeartsLeft ? .feedback(isCorrect: false) : .outOfHearts
    }
}
