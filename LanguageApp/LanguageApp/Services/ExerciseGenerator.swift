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
    /// `example` split into chunks for the sentence builder.
    var exampleTokens: [String]? = nil
}

extension StudyItem {
    init(item: VocabItem, speechLocale: String) {
        self.init(id: item.remoteId,
                  term: item.term,
                  reading: item.reading,
                  meaning: item.meaning.text,
                  example: item.example,
                  exampleMeaning: item.exampleMeaning?.text,
                  speechLocale: speechLocale,
                  exampleTokens: item.exampleTokens)
    }
}

/// One chunk in the sentence builder. `id` is unique even when two chunks have the same text.
struct SentenceTile: Identifiable, Hashable {
    let id: String
    let text: String
}

struct ChoiceOption: Identifiable, Hashable {
    let id: String
    let text: String
    let subtitle: String?
}

enum Exercise: Identifiable, Hashable {
    /// Lesson tip: a rule of the language, shown before the first question (not graded).
    case tip(String)
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
    /// Show meaning → type the term (graded by `AnswerMatcher`).
    case typeTerm(StudyItem)
    /// Play audio → type what you hear.
    case typeListening(StudyItem)
    /// Show the example's meaning → tap the chunks of the example in the right order.
    case buildSentence(StudyItem, tiles: [SentenceTile])
    /// Example sentence with the word blanked out → pick the missing word.
    case fillBlank(StudyItem, before: String, after: String, options: [ChoiceOption])

    var id: String {
        switch self {
        case .tip: return "tip"
        case .introduce(let item): return "intro-\(item.id)"
        case .chooseMeaning(let item, _): return "meaning-\(item.id)"
        case .chooseTerm(let item, _): return "term-\(item.id)"
        case .listen(let item, _): return "listen-\(item.id)"
        case .matchPairs(let items): return "match-" + items.map(\.id).joined(separator: "-")
        case .typeTerm(let item): return "type-\(item.id)"
        case .typeListening(let item): return "typelisten-\(item.id)"
        case .buildSentence(let item, _): return "sentence-\(item.id)"
        case .fillBlank(let item, _, _, _): return "blank-\(item.id)"
        }
    }

    /// Free-text answer instead of options.
    var isTyping: Bool {
        switch self {
        case .typeTerm, .typeListening: return true
        default: return false
        }
    }

    var isGraded: Bool {
        switch self {
        case .tip, .introduce: return false
        default: return true
        }
    }

    /// Correct option id for choice exercises.
    var correctOptionId: String? {
        switch self {
        case .chooseMeaning(let item, _), .chooseTerm(let item, _), .listen(let item, _), .fillBlank(let item, _, _, _):
            return item.id
        default:
            return nil
        }
    }

    var studyItem: StudyItem? {
        switch self {
        case .introduce(let item), .chooseMeaning(let item, _), .chooseTerm(let item, _), .listen(let item, _),
             .typeTerm(let item), .typeListening(let item), .buildSentence(let item, _), .fillBlank(let item, _, _, _):
            return item
        case .tip, .matchPairs:
            return nil
        }
    }
}

struct ExerciseGenerator {
    var optionCount = 4
    var maxMatchPairs = 5
    /// Include typing exercises in the second pass.
    var allowsTyping = true
    /// Question type of the second pass.
    enum SecondPassKind { case chooseTerm, listen, typeTerm, typeListening, buildSentence, fillBlank }

    /// First time through a lesson: more multiple choice, fewer sentence questions.
    /// Replay (and practice): more typing and listening, more sentence questions.
    enum Difficulty { case firstTime, replay }
    var difficulty: Difficulty = .replay
    /// Developer option: every second-pass question uses this type (nil = random mix).
    var forcedSecondPass: SecondPassKind?
    var includesIntroCards = true
    var includesMatchPairs = true
    /// Sentence-builder questions added after the second pass (words with an example sentence).
    var sentenceCount: Int { difficulty == .replay ? 2 : 1 }
    /// Fill-in-the-blank questions added after the second pass.
    var fillBlankCount: Int { difficulty == .replay ? 2 : 1 }
    /// Wrong chunks mixed into the sentence builder.
    var sentenceDistractors = 2
    /// Sentences with more chunks than this are too long for the builder.
    nonisolated static let maxSentenceTokens = 8

    /// - Parameters:
    ///   - items: words of the lesson.
    ///   - distractorPool: other words of the course, used as wrong options.
    ///   - introduceNewWords: add an intro card before the first question of each unseen word.
    ///   - newWordIds: ids of words the learner hasn't met yet.
    ///   - tip: the lesson's tip in the UI language, shown on a card before the first question.
    func makeLesson(items: [StudyItem],
                    distractorPool: [StudyItem],
                    newWordIds: Set<String>,
                    tip: String? = nil,
                    using rng: inout some RandomNumberGenerator) -> [Exercise] {
        guard !items.isEmpty else { return [] }
        let pool = uniquePool(items + distractorPool)
        var exercises: [Exercise] = []

        // The lesson's tip (a rule of the language) comes before everything else.
        if let tip, !tip.isEmpty {
            exercises.append(.tip(tip))
        }

        // Pass 1: meet each word (intro if new) + an easy recognition question.
        for item in items {
            if includesIntroCards, newWordIds.contains(item.id) {
                exercises.append(.introduce(item))
            }
            exercises.append(.chooseMeaning(item, options: meaningOptions(for: item, pool: pool, using: &rng)))
        }

        // Pass 2: harder questions in random order. Typing what you hear is only asked for words
        // the learner has met before; a brand-new word can still be typed from its meaning.
        var second: [Exercise] = []
        for item in items {
            let kinds = secondPassKinds(isNew: newWordIds.contains(item.id))
            let kind = forcedSecondPass ?? kinds[Int.random(in: 0..<kinds.count, using: &rng)]
            second.append(exercise(kind, for: item, pool: pool, using: &rng))
        }
        second.shuffle(using: &rng)
        exercises.append(contentsOf: second)

        // Pass 3: example sentences – build a few from chunks, fill in the blank in others
        // (different words, so the same sentence isn't asked twice). Skipped when a developer
        // option forces one question type.
        if forcedSecondPass == nil {
            var third: [Exercise] = []
            let sentenceItems = Array(items.filter(Self.hasBuildableSentence).shuffled(using: &rng).prefix(sentenceCount))
            for item in sentenceItems {
                if let sentence = sentenceExercise(for: item, pool: pool, using: &rng) { third.append(sentence) }
            }
            let usedIds = Set(sentenceItems.map(\.id))
            let blankItems = items.filter { !usedIds.contains($0.id) && Self.blankParts(of: $0) != nil }
            for item in blankItems.shuffled(using: &rng).prefix(fillBlankCount) {
                if let blank = fillBlankExercise(for: item, pool: pool, using: &rng) { third.append(blank) }
            }
            exercises.append(contentsOf: third.shuffled(using: &rng))
        }

        // Finale: matching pairs.
        if includesMatchPairs, items.count >= 3 {
            let pairs = Array(items.shuffled(using: &rng).prefix(maxMatchPairs))
            exercises.append(.matchPairs(pairs))
        }
        return exercises
    }

    /// Unit checkpoint: no intro cards, no easy recognition pass and no match pairs – one harder
    /// question per word (as when replaying a lesson), then example sentences.
    /// - Parameter intro: text of a card shown first (what the checkpoint is and how to pass).
    func makeCheckpoint(items: [StudyItem],
                        distractorPool: [StudyItem],
                        intro: String? = nil,
                        using rng: inout some RandomNumberGenerator) -> [Exercise] {
        guard !items.isEmpty else { return [] }
        var generator = self
        generator.difficulty = .replay
        let pool = uniquePool(items + distractorPool)
        var exercises: [Exercise] = []
        if let intro, !intro.isEmpty {
            exercises.append(.tip(intro))
        }

        var questions: [Exercise] = []
        for item in items {
            let kinds = generator.secondPassKinds(isNew: false)
            let kind = forcedSecondPass ?? kinds[Int.random(in: 0..<kinds.count, using: &rng)]
            questions.append(generator.exercise(kind, for: item, pool: pool, using: &rng))
        }
        if forcedSecondPass == nil {
            let sentenceItems = Array(items.filter(Self.hasBuildableSentence).shuffled(using: &rng)
                .prefix(generator.sentenceCount))
            for item in sentenceItems {
                if let sentence = sentenceExercise(for: item, pool: pool, using: &rng) { questions.append(sentence) }
            }
            let usedIds = Set(sentenceItems.map(\.id))
            let blankItems = items.filter { !usedIds.contains($0.id) && Self.blankParts(of: $0) != nil }
            for item in blankItems.shuffled(using: &rng).prefix(generator.fillBlankCount) {
                if let blank = fillBlankExercise(for: item, pool: pool, using: &rng) { questions.append(blank) }
            }
        }
        exercises.append(contentsOf: questions.shuffled(using: &rng))
        return exercises
    }

    /// Weighted list of second-pass question types (picked uniformly, so repeats = more likely).
    func secondPassKinds(isNew: Bool) -> [SecondPassKind] {
        guard allowsTyping else { return [.chooseTerm, .listen] }
        switch (difficulty, isNew) {
        case (.firstTime, true): return [.chooseTerm, .chooseTerm, .listen, .typeTerm]
        case (.firstTime, false): return [.chooseTerm, .listen, .typeTerm, .typeListening]
        case (.replay, true): return [.chooseTerm, .listen, .typeTerm, .typeTerm]
        case (.replay, false): return [.chooseTerm, .listen, .typeTerm, .typeTerm, .typeListening, .typeListening]
        }
    }

    /// One question of the given type; sentence questions fall back to "choose the word" for words
    /// without a usable example (developer option that forces a type).
    private func exercise(_ kind: SecondPassKind, for item: StudyItem, pool: [StudyItem],
                          using rng: inout some RandomNumberGenerator) -> Exercise {
        switch kind {
        case .chooseTerm:
            return .chooseTerm(item, options: termOptions(for: item, pool: pool, using: &rng))
        case .listen:
            return .listen(item, options: termOptions(for: item, pool: pool, using: &rng))
        case .typeTerm:
            return .typeTerm(item)
        case .typeListening:
            return .typeListening(item)
        case .buildSentence:
            if let sentence = sentenceExercise(for: item, pool: pool, using: &rng) { return sentence }
        case .fillBlank:
            if let blank = fillBlankExercise(for: item, pool: pool, using: &rng) { return blank }
        }
        return .chooseTerm(item, options: termOptions(for: item, pool: pool, using: &rng))
    }

    // MARK: - Fill in the blank

    /// Splits the example around the word as written: "I like to ___ rice." In Latin-script languages
    /// the match must be a whole word ("car" is not found in "card"). nil → the example can't be used.
    nonisolated static func blankParts(of item: StudyItem) -> (before: String, after: String)? {
        guard let example = item.example, !item.term.isEmpty, item.exampleMeaning?.isEmpty == false else { return nil }
        var searchStart = example.startIndex
        while let range = example.range(of: item.term, options: .caseInsensitive, range: searchStart..<example.endIndex) {
            let before = range.lowerBound > example.startIndex ? example[example.index(before: range.lowerBound)] : nil
            let after = range.upperBound < example.endIndex ? example[range.upperBound] : nil
            let needsWordBoundary = item.term.first.map(isLatinLetter) ?? false
            if !needsWordBoundary || (!(before.map(isLatinLetter) ?? false) && !(after.map(isLatinLetter) ?? false)) {
                return (String(example[..<range.lowerBound]), String(example[range.upperBound...]))
            }
            searchStart = range.upperBound
        }
        return nil
    }

    nonisolated private static func isLatinLetter(_ character: Character) -> Bool {
        guard character.isLetter, let scalar = character.unicodeScalars.first else { return false }
        return scalar.value < 0x0250 || (0x1E00...0x1EFF).contains(scalar.value)   // incl. Vietnamese
    }

    func fillBlankExercise(for item: StudyItem, pool: [StudyItem],
                           using rng: inout some RandomNumberGenerator) -> Exercise? {
        guard let parts = Self.blankParts(of: item) else { return nil }
        return .fillBlank(item, before: parts.before, after: parts.after,
                          options: termOptions(for: item, pool: pool, using: &rng))
    }

    // MARK: - Sentence builder

    nonisolated static func hasBuildableSentence(_ item: StudyItem) -> Bool {
        guard let tokens = item.exampleTokens, item.exampleMeaning?.isEmpty == false else { return false }
        return (2...maxSentenceTokens).contains(tokens.count)
    }

    /// The example's chunks plus a few chunks from other sentences, shuffled.
    func sentenceExercise(for item: StudyItem, pool: [StudyItem],
                          using rng: inout some RandomNumberGenerator) -> Exercise? {
        guard Self.hasBuildableSentence(item), let tokens = item.exampleTokens else { return nil }
        var tiles = tokens.enumerated().map { SentenceTile(id: "\(item.id)-\($0.offset)", text: $0.element) }
        var used = Set(tokens)
        let others = pool
            .filter { $0.id != item.id }
            .flatMap { $0.exampleTokens ?? [] }
            .shuffled(using: &rng)
        for (index, token) in others.enumerated() where tiles.count < tokens.count + sentenceDistractors {
            guard used.insert(token).inserted else { continue }
            tiles.append(SentenceTile(id: "\(item.id)-x\(index)", text: token))
        }
        return .buildSentence(item, tiles: tiles.shuffled(using: &rng))
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
