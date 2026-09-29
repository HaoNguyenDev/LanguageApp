//
//  ExerciseGenerator.swift
//  LanguageApp
//
//  Builds a Duolingo-style exercise sequence from a lesson's words.
//  Pure value types → easy to unit test with a seeded RNG.
//

import Foundation

/// Snapshot of a `VocabItem` resolved for the current UI language.
struct StudyItem: Identifiable, Hashable {
    let id: String
    let term: String
    let reading: String?
    let meaning: String
    let example: String?
    let exampleMeaning: String?
    let speechLocale: String
}

extension StudyItem {
    init(item: VocabItem, speechLocale: String) {
        self.init(id: item.remoteId,
                  term: item.term,
                  reading: item.reading,
                  meaning: item.meaning.text,
                  example: item.example,
                  exampleMeaning: item.exampleMeaning?.text,
                  speechLocale: speechLocale)
    }
}

struct ChoiceOption: Identifiable, Hashable {
    let id: String
    let text: String
    let subtitle: String?
}

enum Exercise: Identifiable, Hashable {
    /// New word card (not graded).
    case introduce(StudyItem)
    /// Show term → pick meaning.
    case chooseMeaning(StudyItem, options: [ChoiceOption])
    /// Show meaning → pick term.
    case chooseTerm(StudyItem, options: [ChoiceOption])
    /// Play audio → pick term.
    case listen(StudyItem, options: [ChoiceOption])
    /// Tap matching pairs (term ↔ meaning).
    case matchPairs([StudyItem])

    var id: String {
        switch self {
        case .introduce(let item): return "intro-\(item.id)"
        case .chooseMeaning(let item, _): return "meaning-\(item.id)"
        case .chooseTerm(let item, _): return "term-\(item.id)"
        case .listen(let item, _): return "listen-\(item.id)"
        case .matchPairs(let items): return "match-" + items.map(\.id).joined(separator: "-")
        }
    }

    var isGraded: Bool {
        if case .introduce = self { return false }
        return true
    }

    /// Correct option id for choice exercises.
    var correctOptionId: String? {
        switch self {
        case .chooseMeaning(let item, _), .chooseTerm(let item, _), .listen(let item, _):
            return item.id
        default:
            return nil
        }
    }

    var studyItem: StudyItem? {
        switch self {
        case .introduce(let item), .chooseMeaning(let item, _), .chooseTerm(let item, _), .listen(let item, _):
            return item
        case .matchPairs:
            return nil
        }
    }
}

struct ExerciseGenerator {
    var optionCount = 4
    var maxMatchPairs = 5

    /// - Parameters:
    ///   - items: words of the lesson.
    ///   - distractorPool: other words of the course, used as wrong options.
    ///   - introduceNewWords: add an intro card before the first question of each unseen word.
    ///   - newWordIds: ids of words the learner hasn't met yet.
    func makeLesson(items: [StudyItem],
                    distractorPool: [StudyItem],
                    newWordIds: Set<String>,
                    using rng: inout some RandomNumberGenerator) -> [Exercise] {
        guard !items.isEmpty else { return [] }
        let pool = uniquePool(items + distractorPool)
        var exercises: [Exercise] = []

        // Pass 1: meet each word (intro if new) + an easy recognition question.
        for item in items {
            if newWordIds.contains(item.id) {
                exercises.append(.introduce(item))
            }
            exercises.append(.chooseMeaning(item, options: meaningOptions(for: item, pool: pool, using: &rng)))
        }

        // Pass 2: harder questions in random order.
        var second: [Exercise] = []
        for item in items {
            let kind = Int.random(in: 0..<2, using: &rng)
            if kind == 0 {
                second.append(.chooseTerm(item, options: termOptions(for: item, pool: pool, using: &rng)))
            } else {
                second.append(.listen(item, options: termOptions(for: item, pool: pool, using: &rng)))
            }
        }
        second.shuffle(using: &rng)
        exercises.append(contentsOf: second)

        // Finale: matching pairs.
        if items.count >= 3 {
            let pairs = Array(items.shuffled(using: &rng).prefix(maxMatchPairs))
            exercises.append(.matchPairs(pairs))
        }
        return exercises
    }

    // MARK: - Options

    func meaningOptions(for item: StudyItem, pool: [StudyItem], using rng: inout some RandomNumberGenerator) -> [ChoiceOption] {
        let distractors = pool
            .filter { $0.id != item.id && $0.meaning != item.meaning }
            .shuffled(using: &rng)
        var seen = Set([item.meaning])
        var options = [ChoiceOption(id: item.id, text: item.meaning, subtitle: nil)]
        for candidate in distractors where options.count < optionCount {
            guard seen.insert(candidate.meaning).inserted else { continue }
            options.append(ChoiceOption(id: candidate.id, text: candidate.meaning, subtitle: nil))
        }
        return options.shuffled(using: &rng)
    }

    func termOptions(for item: StudyItem, pool: [StudyItem], using rng: inout some RandomNumberGenerator) -> [ChoiceOption] {
        let distractors = pool
            .filter { $0.id != item.id && $0.term != item.term }
            .shuffled(using: &rng)
        var seen = Set([item.term])
        var options = [ChoiceOption(id: item.id, text: item.term, subtitle: item.reading)]
        for candidate in distractors where options.count < optionCount {
            guard seen.insert(candidate.term).inserted else { continue }
            options.append(ChoiceOption(id: candidate.id, text: candidate.term, subtitle: candidate.reading))
        }
        return options.shuffled(using: &rng)
    }

    private func uniquePool(_ items: [StudyItem]) -> [StudyItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}

/// Deterministic RNG for tests / reproducible sessions (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
