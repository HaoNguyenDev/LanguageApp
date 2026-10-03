//
//  LanguageAppTests.swift
//  LanguageAppTests
//
//  Created by Hao Nguyen on 29/09/2026.
//

import XCTest
import SwiftData
import AVFoundation
@testable import LanguageApp

@MainActor
final class SRSSchedulerTests: XCTestCase {
    // Fixtures as computed properties so every test gets fresh values.
    private var scheduler: SRSScheduler { SRSScheduler() }
    private var now: Date { Date(timeIntervalSince1970: 1_800_000_000) }
    private var day: TimeInterval { 86_400 }

    func testIntroduceSchedulesTomorrow() {
        let state = scheduler.introduce(now: now)
        XCTAssertEqual(state.reps, 1)
        XCTAssertEqual(state.due, now.addingTimeInterval(day))
    }

    func testGoodGrowsInterval() {
        var state = scheduler.introduce(now: now)
        state = scheduler.schedule(state, grade: .good, now: now)
        XCTAssertEqual(state.interval, 3, accuracy: 0.01)
        let previous = state.interval
        state = scheduler.schedule(state, grade: .good, now: now)
        XCTAssertGreaterThan(state.interval, previous * 2)
        XCTAssertEqual(state.reps, 3)
    }

    func testAgainResetsAndLowersEase() {
        var state = scheduler.introduce(now: now)
        state = scheduler.schedule(state, grade: .good, now: now)
        let lapsed = scheduler.schedule(state, grade: .again, now: now)
        XCTAssertEqual(lapsed.reps, 0)
        XCTAssertEqual(lapsed.lapses, 1)
        XCTAssertEqual(lapsed.interval, 0)
        XCTAssertLessThan(lapsed.ease, state.ease)
        XCTAssertEqual(lapsed.due, now.addingTimeInterval(scheduler.relearnDelay))
    }

    func testEaseNeverBelowMinimum() {
        var state = SRSState(reps: 3, interval: 10, ease: 1.35, lapses: 0, due: now)
        for _ in 0..<5 { state = scheduler.schedule(state, grade: .again, now: now) }
        XCTAssertEqual(state.ease, scheduler.minimumEase, accuracy: 0.0001)
    }

    func testGradeOrderingOfIntervals() {
        let state = SRSState(reps: 2, interval: 3, ease: 2.5, lapses: 0, due: now)
        let preview = scheduler.preview(state, now: now)
        XCTAssertLessThan(preview[.again]!, preview[.hard]!)
        XCTAssertLessThan(preview[.hard]!, preview[.good]!)
        XCTAssertLessThan(preview[.good]!, preview[.easy]!)
    }

    /// A word just learned in a lesson (first review): every button shows a different time.
    func testFirstReviewButtonLabels() {
        let state = scheduler.introduce(now: now)
        let labels = scheduler.preview(state, now: now).mapValues { SRSScheduler.shortLabel(for: $0) }
        XCTAssertEqual(labels[.again], "10m")
        XCTAssertEqual(labels[.hard], "1d")
        XCTAssertEqual(labels[.good], "3d")
        XCTAssertEqual(labels[.easy], "5d")
    }

    /// Again < Hard ≤ Good < Easy for every kind of card (new, relearning, young, mature,
    /// low / high ease), and Easy is always at least `easyBonusDays` later than Good.
    func testGradeOrderingForManyStates() {
        let states: [SRSState] = [
            SRSState(reps: 0, interval: 0, ease: 2.5, lapses: 1, due: now),     // relearning after Again
            scheduler.introduce(now: now),                                       // first review
            SRSState(reps: 1, interval: 1, ease: 1.3, lapses: 2, due: now),     // hard word
            SRSState(reps: 2, interval: 3, ease: 2.5, lapses: 0, due: now),
            SRSState(reps: 4, interval: 20, ease: 2.8, lapses: 0, due: now),
            SRSState(reps: 6, interval: 90, ease: 1.3, lapses: 3, due: now)
        ]
        for state in states {
            let preview = scheduler.preview(state, now: now)
            let again = preview[.again]!, hard = preview[.hard]!, good = preview[.good]!, easy = preview[.easy]!
            XCTAssertLessThan(again, hard, "\(state)")
            XCTAssertLessThanOrEqual(hard, good, "\(state)")
            XCTAssertLessThan(good, easy, "\(state)")
            XCTAssertGreaterThanOrEqual(easy - good, scheduler.easyBonusDays * day - 0.1 * day, "\(state)")
            XCTAssertNotEqual(SRSScheduler.shortLabel(for: good), SRSScheduler.shortLabel(for: easy),
                              "Good and Easy must not show the same time: \(state)")
        }
    }

    func testIntervalsNeverExceedTheMaximum() {
        let mature = SRSState(reps: 10, interval: 300, ease: 3, lapses: 0, due: now)
        for grade in ReviewGrade.allCases {
            XCTAssertLessThanOrEqual(scheduler.schedule(mature, grade: grade, now: now).interval,
                                     scheduler.maximumIntervalDays)
        }
    }

    func testEasyRaisesEaseAndHardLowersIt() {
        let state = SRSState(reps: 2, interval: 3, ease: 2.5, lapses: 0, due: now)
        XCTAssertEqual(scheduler.schedule(state, grade: .easy, now: now).ease, 2.65, accuracy: 0.0001)
        XCTAssertEqual(scheduler.schedule(state, grade: .hard, now: now).ease, 2.35, accuracy: 0.0001)
        XCTAssertEqual(scheduler.schedule(state, grade: .good, now: now).ease, 2.5, accuracy: 0.0001)
    }

    func testShortLabels() {
        XCTAssertEqual(SRSScheduler.shortLabel(for: 600), "10m")
        XCTAssertEqual(SRSScheduler.shortLabel(for: day), "1d")
        XCTAssertEqual(SRSScheduler.shortLabel(for: 60 * day), "2mo")
        XCTAssertEqual(SRSScheduler.shortLabel(for: 56 * day), "1.9mo")
        XCTAssertEqual(SRSScheduler.shortLabel(for: 365 * day), "1y")
        XCTAssertEqual(SRSScheduler.shortLabel(for: 438 * day), "1.2y")
    }
}

@MainActor
final class ExerciseGeneratorTests: XCTestCase {
    private func item(_ i: Int) -> StudyItem {
        StudyItem(id: "w\(i)", term: "term\(i)", reading: nil, meaning: "meaning\(i)",
                  example: nil, exampleMeaning: nil, speechLocale: "en-US")
    }

    func testLessonStructure() {
        let items = (1...6).map(item)
        let pool = (7...12).map(item)
        var rng = SeededGenerator(seed: 42)
        let exercises = ExerciseGenerator().makeLesson(items: items, distractorPool: pool,
                                                       newWordIds: Set(items.map(\.id)), using: &rng)
        // 6 intros + 6 recognition + 6 harder + 1 match
        XCTAssertEqual(exercises.count, 19)
        XCTAssertEqual(exercises.filter { !$0.isGraded }.count, 6)
        if case .matchPairs(let pairs) = exercises.last {
            XCTAssertEqual(pairs.count, 5)
        } else {
            XCTFail("Last exercise should be match pairs")
        }
    }

    func testOptionsContainCorrectAnswerAndAreUnique() {
        let items = (1...6).map(item)
        var rng = SeededGenerator(seed: 7)
        let exercises = ExerciseGenerator().makeLesson(items: items, distractorPool: [], newWordIds: [], using: &rng)
        for exercise in exercises {
            switch exercise {
            case .chooseMeaning(let target, let options), .chooseTerm(let target, let options), .listen(let target, let options):
                XCTAssertEqual(options.count, 4)
                XCTAssertTrue(options.contains { $0.id == target.id })
                XCTAssertEqual(Set(options.map(\.text)).count, options.count)
            default:
                break
            }
        }
    }

    func testTypingExercises() {
        let items = (1...6).map(item)
        var rng = SeededGenerator(seed: 3)
        // Seen words: every pass-2 kind is possible, including typing what you hear.
        var kinds = Set<String>()
        for _ in 0..<20 {
            for exercise in ExerciseGenerator().makeLesson(items: items, distractorPool: [], newWordIds: [], using: &rng) {
                if case .typeTerm = exercise { kinds.insert("typeTerm") }
                if case .typeListening = exercise { kinds.insert("typeListening") }
            }
        }
        XCTAssertEqual(kinds, ["typeTerm", "typeListening"])

        // New words are never asked as "type what you hear".
        let newIds = Set(items.map(\.id))
        for _ in 0..<20 {
            let exercises = ExerciseGenerator().makeLesson(items: items, distractorPool: [], newWordIds: newIds, using: &rng)
            XCTAssertFalse(exercises.contains { if case .typeListening = $0 { return true } else { return false } })
        }

        // Typing can be switched off.
        var noTyping = ExerciseGenerator()
        noTyping.allowsTyping = false
        let exercises = noTyping.makeLesson(items: items, distractorPool: [], newWordIds: [], using: &rng)
        XCTAssertFalse(exercises.contains(where: \.isTyping))
    }

    private func sentenceItem(_ i: Int, tokens: [String]) -> StudyItem {
        StudyItem(id: "s\(i)", term: tokens[0], reading: nil, meaning: "m\(i)",
                  example: tokens.joined(separator: " "), exampleMeaning: "meaning of sentence \(i)",
                  speechLocale: "en-US", exampleTokens: tokens)
    }

    func testSentenceBuilderExercises() throws {
        let items = [
            sentenceItem(1, tokens: ["I", "am", "a", "student."]),
            sentenceItem(2, tokens: ["The", "cat", "is", "black."]),
            sentenceItem(3, tokens: ["Hello!"]),                       // single chunk → not buildable
        ] + (4...6).map(item)
        var rng = SeededGenerator(seed: 11)
        let exercises = ExerciseGenerator().makeLesson(items: items, distractorPool: [], newWordIds: [], using: &rng)
        let sentences = exercises.compactMap { exercise -> (StudyItem, [SentenceTile])? in
            if case .buildSentence(let item, let tiles) = exercise { return (item, tiles) }
            return nil
        }
        XCTAssertEqual(Set(sentences.map { $0.0.id }), ["s1", "s2"], "Two buildable sentences per lesson")
        for (item, tiles) in sentences {
            let answer = try XCTUnwrap(item.exampleTokens)
            XCTAssertEqual(tiles.count, answer.count + 2, "answer chunks + 2 distractors")
            XCTAssertEqual(Set(tiles.map(\.id)).count, tiles.count, "tile ids are unique")
            XCTAssertTrue(Set(answer).isSubset(of: Set(tiles.map(\.text))))
        }
        // Sentence questions come before the final match pairs.
        if case .matchPairs = exercises.last {} else { XCTFail("Match pairs should stay last") }
    }

    private func exampleItem(_ id: String, term: String, example: String) -> StudyItem {
        StudyItem(id: id, term: term, reading: nil, meaning: "m", example: example, exampleMeaning: "meaning",
                  speechLocale: "en-US", exampleTokens: example.split(separator: " ").map(String.init))
    }

    func testBlankPartsMatchWholeWordsInLatinScripts() throws {
        let car = try XCTUnwrap(ExerciseGenerator.blankParts(of: exampleItem("a", term: "car", example: "My card and my car.")))
        XCTAssertEqual(car.before, "My card and my ")
        XCTAssertEqual(car.after, ".")
        let young = try XCTUnwrap(ExerciseGenerator.blankParts(of: exampleItem("b", term: "trẻ", example: "Giáo viên của tôi còn trẻ.")))
        XCTAssertEqual(young.after, ".")
        // Case-insensitive, at the start of the sentence.
        XCTAssertEqual(ExerciseGenerator.blankParts(of: exampleItem("c", term: "hola", example: "Hola, ¿cómo estás?"))?.after, ", ¿cómo estás?")
        // Japanese: no word boundaries.
        let cat = try XCTUnwrap(ExerciseGenerator.blankParts(of: exampleItem("d", term: "猫", example: "猫が好きです。")))
        XCTAssertEqual(cat.before, "")
        XCTAssertEqual(cat.after, "が好きです。")
        // Conjugated form → the word isn't in the sentence as written.
        XCTAssertNil(ExerciseGenerator.blankParts(of: exampleItem("e", term: "먹다", example: "밥을 먹어요.")))
    }

    func testThirdPassMixesSentenceBuilderAndFillInTheBlank() {
        let items = [
            exampleItem("w1", term: "student", example: "I am a student."),
            exampleItem("w2", term: "cat", example: "The cat is black."),
            exampleItem("w3", term: "tea", example: "I drink tea."),
            exampleItem("w4", term: "bread", example: "I eat bread."),
        ]
        for difficulty in [ExerciseGenerator.Difficulty.firstTime, .replay] {
            var generator = ExerciseGenerator()
            generator.difficulty = difficulty
            var rng = SeededGenerator(seed: 21)
            let exercises = generator.makeLesson(items: items, distractorPool: [], newWordIds: [], using: &rng)
            var sentenceIds: [String] = [], blankIds: [String] = []
            for exercise in exercises {
                if case .buildSentence(let item, _) = exercise { sentenceIds.append(item.id) }
                if case .fillBlank(let item, let before, let after, let options) = exercise {
                    blankIds.append(item.id)
                    XCTAssertEqual(before + item.term + after, item.example)
                    XCTAssertTrue(options.contains { $0.id == item.id })
                }
            }
            let expected = difficulty == .replay ? 2 : 1
            XCTAssertEqual(sentenceIds.count, expected, "\(difficulty)")
            XCTAssertEqual(blankIds.count, expected, "\(difficulty)")
            XCTAssertTrue(Set(sentenceIds).isDisjoint(with: blankIds), "the same sentence isn't asked twice")
        }
    }

    func testReplayAsksMoreTypingThanFirstTime() {
        let items = (1...6).map(item)
        func typingCount(_ difficulty: ExerciseGenerator.Difficulty, newWords: Bool) -> Int {
            var generator = ExerciseGenerator()
            generator.difficulty = difficulty
            var rng = SeededGenerator(seed: 99)
            return (0..<200).reduce(0) { total, _ in
                total + generator.makeLesson(items: items, distractorPool: [],
                                             newWordIds: newWords ? Set(items.map(\.id)) : [], using: &rng)
                    .filter(\.isTyping).count
            }
        }
        XCTAssertGreaterThan(typingCount(.replay, newWords: false), typingCount(.firstTime, newWords: false))
        XCTAssertGreaterThan(typingCount(.replay, newWords: true), typingCount(.firstTime, newWords: true))
        XCTAssertEqual(ExerciseGenerator().secondPassKinds(isNew: true).filter { $0 == .typeListening }.count, 0)
    }

    func testDeveloperGeneratorOptions() {
        let items = (1...6).map(item)
        var rng = SeededGenerator(seed: 5)
        var generator = ExerciseGenerator()
        generator.includesIntroCards = false
        generator.includesMatchPairs = false
        generator.forcedSecondPass = .typeListening
        let exercises = generator.makeLesson(items: items, distractorPool: [], newWordIds: Set(items.map(\.id)), using: &rng)
        XCTAssertEqual(exercises.count, 12, "6 recognition + 6 forced questions, no intros, no match pairs")
        XCTAssertEqual(exercises.suffix(6).filter { if case .typeListening = $0 { return true } else { return false } }.count, 6)
    }

    func testTipComesFirstAndIsNotGraded() {
        let items = (1...6).map(item)
        var rng = SeededGenerator(seed: 7)
        let exercises = ExerciseGenerator().makeLesson(items: items, distractorPool: [], newWordIds: [],
                                                       tip: "13–19 = number + -teen", using: &rng)
        XCTAssertEqual(exercises.first, .tip("13–19 = number + -teen"))
        XCTAssertFalse(exercises[0].isGraded)
        XCTAssertNil(exercises[0].studyItem)
        XCTAssertEqual(exercises.filter { if case .tip = $0 { return true } else { return false } }.count, 1)

        var rng2 = SeededGenerator(seed: 7)
        let withoutTip = ExerciseGenerator().makeLesson(items: items, distractorPool: [], newWordIds: [],
                                                        tip: "", using: &rng2)
        XCTAssertEqual(withoutTip.count, exercises.count - 1, "An empty tip adds no card")
    }

    func testSeededGeneratorIsDeterministic() {
        let items = (1...5).map(item)
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 1)
        let first = ExerciseGenerator().makeLesson(items: items, distractorPool: [], newWordIds: [], using: &a)
        let second = ExerciseGenerator().makeLesson(items: items, distractorPool: [], newWordIds: [], using: &b)
        XCTAssertEqual(first, second)
    }
}

@MainActor
final class AnswerMatcherTests: XCTestCase {
    private func word(_ term: String, _ reading: String? = nil, locale: String = "en-US") -> StudyItem {
        StudyItem(id: term, term: term, reading: reading, meaning: "m", example: nil, exampleMeaning: nil, speechLocale: locale)
    }

    func testExactAnswerIgnoresCasePunctuationAndSpaces() {
        XCTAssertEqual(AnswerMatcher.grade("  Hello! ", for: word("hello")), .correct)
        XCTAssertEqual(AnswerMatcher.grade("¿Cuánto cuesta?", for: word("cuánto cuesta", locale: "es-ES")), .correct)
    }

    func testMissingAccentOrToneIsAlmost() {
        XCTAssertEqual(AnswerMatcher.grade("xin chao", for: word("xin chào", locale: "vi-VN")), .almost)
        XCTAssertEqual(AnswerMatcher.grade("adios", for: word("adiós", locale: "es-ES")), .almost)
        XCTAssertEqual(AnswerMatcher.grade("trung", for: word("trứng", locale: "vi-VN")), .almost)
    }

    func testOneTypoInLongLatinWordIsAlmost() {
        XCTAssertEqual(AnswerMatcher.grade("famly", for: word("family")), .almost)
        XCTAssertEqual(AnswerMatcher.grade("fmly", for: word("family")), .wrong)
        // Short words need the exact letters.
        XCTAssertEqual(AnswerMatcher.grade("cat", for: word("car")), .wrong)
    }

    func testJapaneseAcceptsKanjiKanaAndRomaji() {
        let mizu = word("水", "みず · mizu", locale: "ja-JP")
        XCTAssertEqual(AnswerMatcher.grade("水", for: mizu), .correct)
        XCTAssertEqual(AnswerMatcher.grade("みず", for: mizu), .correct)
        XCTAssertEqual(AnswerMatcher.grade("ミズ", for: mizu), .correct)
        XCTAssertEqual(AnswerMatcher.grade("Mizu", for: mizu), .correct)
        XCTAssertEqual(AnswerMatcher.grade("みそ", for: mizu), .wrong)

        let kyou = word("今日", "きょう · kyō", locale: "ja-JP")
        XCTAssertEqual(AnswerMatcher.grade("kyo", for: kyou), .correct)
        XCTAssertEqual(AnswerMatcher.grade("kyou", for: kyou), .correct)
        XCTAssertEqual(AnswerMatcher.grade("kyoo", for: kyou), .correct)
    }

    func testChineseAndKoreanAcceptRomanizationWithoutTones() {
        let nihao = word("你好", "nǐ hǎo", locale: "zh-CN")
        XCTAssertEqual(AnswerMatcher.grade("你好", for: nihao), .correct)
        XCTAssertEqual(AnswerMatcher.grade("ni hao", for: nihao), .correct)
        XCTAssertEqual(AnswerMatcher.grade("nihao", for: nihao), .correct)

        let mul = word("물", "mul", locale: "ko-KR")
        XCTAssertEqual(AnswerMatcher.grade("물", for: mul), .correct)
        XCTAssertEqual(AnswerMatcher.grade("mul", for: mul), .correct)
        XCTAssertEqual(AnswerMatcher.grade("불", for: mul), .wrong)
    }

    func testIPAIsNotAcceptedAsAnswer() {
        XCTAssertEqual(AnswerMatcher.grade("wɔːtər", for: word("water", "/ˈwɔːtər/")), .wrong)
        XCTAssertEqual(AnswerMatcher.grade("", for: word("water")), .wrong)
    }
}

@MainActor
final class PracticeServiceTests: XCTestCase {
    private typealias Candidate = PracticeService.Candidate

    func testWeakness() {
        let solid = Candidate(id: "a", interval: 20)
        XCTAssertEqual(PracticeService.weakness(solid), 0)
        XCTAssertGreaterThan(PracticeService.weakness(Candidate(id: "b", mistakes: 1, interval: 20)), 0)
        XCTAssertGreaterThan(PracticeService.weakness(Candidate(id: "c", lapses: 2, ease: 1.8, interval: 20)),
                             PracticeService.weakness(Candidate(id: "d", lapses: 1, interval: 20)))
        // A recently learned word (short interval) counts as weak, like `WordStrength.weak`.
        XCTAssertEqual(PracticeService.weakness(Candidate(id: "e", interval: 1)), 1)
    }

    func testPickWordsWeakestFirstAndTopsUp() {
        let words = [
            Candidate(id: "solid1", interval: 30),
            Candidate(id: "mistakes", mistakes: 3, interval: 10),
            Candidate(id: "lapsed", lapses: 1, ease: 2.2, interval: 5),
            Candidate(id: "solid2", interval: 8),
            Candidate(id: "new", interval: 1),
        ]
        XCTAssertEqual(PracticeService.pickWords(words, limit: 4), ["mistakes", "lapsed", "new", "solid2"])
        XCTAssertEqual(PracticeService.weakCount(words), 3)
    }

    func testNoPracticeWithTooFewWords() {
        let words = (0..<(PracticeService.minimumWords - 1)).map { Candidate(id: "w\($0)", mistakes: 2) }
        XCTAssertTrue(PracticeService.pickWords(words).isEmpty)
    }

    func testRecordMistakes() {
        // SwiftData models need a container in the process before they can be created.
        let container = PersistenceController.makeContainer(inMemory: true)
        let missed = VocabItem(remoteId: "a", courseId: "en")
        let correct = VocabItem(remoteId: "b", courseId: "en")
        container.mainContext.insert(missed)
        container.mainContext.insert(correct)
        correct.mistakeCount = 2
        PracticeService.recordMistakes(["a": 2], for: [missed, correct], forgiveCorrect: false)
        XCTAssertEqual(missed.mistakeCount, 2)
        XCTAssertNotNil(missed.lastMistakeAt)
        XCTAssertEqual(correct.mistakeCount, 2, "Lessons don't forgive mistakes")

        PracticeService.recordMistakes([:], for: [missed, correct], forgiveCorrect: true)
        XCTAssertEqual(missed.mistakeCount, 1)
        XCTAssertEqual(correct.mistakeCount, 1)
    }
}

@MainActor
final class DebugSettingsTests: XCTestCase {
    /// Developer switches never take effect while unit tests run (same as Release builds).
    func testSwitchesAreOffOutsideTheDeveloperMenuEnvironment() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "DebugSettingsTests"))
        defaults.removePersistentDomain(forName: "DebugSettingsTests")
        let debug = DebugSettings(defaults: defaults)
        debug.unlockAllLessons = true
        debug.premiumOverride = .plus
        debug.shortLessons = true
        XCTAssertFalse(DebugSettings.isAvailable)
        XCTAssertFalse(debug.unlocksAllLessons)
        XCTAssertNil(debug.forcedPremium)
        XCTAssertNil(debug.lessonWordLimit)
        XCTAssertEqual(debug.activeCount, 0)

        // Stored values persist for the developer menu.
        XCTAssertTrue(DebugSettings(defaults: defaults).unlockAllLessons)
        defaults.removePersistentDomain(forName: "DebugSettingsTests")
    }
}

@MainActor
final class LessonSessionViewModelTests: XCTestCase {
    private var word: StudyItem { StudyItem(id: "a", term: "hola", reading: nil, meaning: "hello",
                                 example: nil, exampleMeaning: nil, speechLocale: "es-ES") }

    private func choice() -> Exercise {
        .chooseMeaning(word, options: [ChoiceOption(id: "a", text: "hello", subtitle: nil),
                                       ChoiceOption(id: "b", text: "bye", subtitle: nil)])
    }

    func testCorrectAnswerFlow() {
        let vm = LessonSessionViewModel(lessonTitle: "t", exercises: [choice()])
        vm.select("a")
        XCTAssertTrue(vm.check())
        XCTAssertEqual(vm.phase, .feedback(isCorrect: true))
        vm.next()
        XCTAssertEqual(vm.phase, .finished)
        XCTAssertEqual(vm.accuracy, 1)
    }

    func testTipCardIsSkippedWithContinue() {
        let vm = LessonSessionViewModel(lessonTitle: "t", exercises: [.tip("rule"), choice()])
        XCTAssertFalse(vm.canCheck)
        vm.next()
        XCTAssertEqual(vm.currentIndex, 1)
        vm.select("a")
        XCTAssertTrue(vm.check())
        vm.next()
        XCTAssertEqual(vm.phase, .finished)
        XCTAssertEqual(vm.accuracy, 1, "The tip card is not graded")
    }

    func testTypingAnswerFlow() {
        let vm = LessonSessionViewModel(lessonTitle: "t", exercises: [.typeTerm(word), .typeTerm(word)])
        XCTAssertFalse(vm.canCheck)
        vm.typedAnswer = "  "
        XCTAssertFalse(vm.canCheck)
        vm.typedAnswer = "Hola"
        XCTAssertTrue(vm.check())
        XCTAssertFalse(vm.lastAnswerWasAlmost)
        vm.next()
        XCTAssertEqual(vm.typedAnswer, "")
        vm.typedAnswer = "adios"
        XCTAssertFalse(vm.check())
        XCTAssertEqual(vm.exercises.count, 3, "A wrong typed answer is re-queued")
    }

    func testMistakesAreCountedPerWord() {
        let vm = LessonSessionViewModel(lessonTitle: "t", exercises: [choice()])
        vm.select("b")
        vm.check()
        vm.next()
        vm.select("b")
        vm.check()
        XCTAssertEqual(vm.mistakesByItemId, ["a": 2])
    }

    func testSentenceBuilderFlow() {
        let item = StudyItem(id: "s", term: "猫", reading: nil, meaning: "cat", example: "猫が好きです。",
                             exampleMeaning: "I like cats.", speechLocale: "ja-JP", exampleTokens: ["猫が", "好きです。"])
        let tiles = [SentenceTile(id: "b", text: "好きです。"), SentenceTile(id: "x", text: "犬が"), SentenceTile(id: "a", text: "猫が")]
        let vm = LessonSessionViewModel(lessonTitle: "t", exercises: [.buildSentence(item, tiles: tiles), .buildSentence(item, tiles: tiles)])
        XCTAssertFalse(vm.canCheck)
        vm.toggleTile("a")
        vm.toggleTile("x")
        vm.toggleTile("x")            // tapping again removes it
        vm.toggleTile("b")
        XCTAssertEqual(vm.arrangedTileIds, ["a", "b"])
        XCTAssertTrue(vm.check())
        vm.next()
        XCTAssertTrue(vm.arrangedTileIds.isEmpty)
        vm.toggleTile("b")
        vm.toggleTile("a")
        XCTAssertFalse(vm.check(), "Wrong order")
        XCTAssertEqual(vm.mistakesByItemId, ["s": 1])
    }

    func testSentenceCheckComparesTextsNotIds() {
        let tiles = [SentenceTile(id: "1", text: "a"), SentenceTile(id: "2", text: "b"), SentenceTile(id: "3", text: "a")]
        XCTAssertTrue(LessonSessionViewModel.isSentenceCorrect(arranged: ["3", "2", "1"], tiles: tiles, answer: ["a", "b", "a"]))
        XCTAssertFalse(LessonSessionViewModel.isSentenceCorrect(arranged: ["1", "2"], tiles: tiles, answer: ["a", "b", "a"]))
    }

    func testWrongAnswerIsRequeuedOnce() {
        let vm = LessonSessionViewModel(lessonTitle: "t", exercises: [choice()])
        vm.select("b")
        XCTAssertFalse(vm.check())
        XCTAssertEqual(vm.exercises.count, 2)
        vm.next()
        vm.select("b")
        vm.check()
        XCTAssertEqual(vm.exercises.count, 2, "Same exercise is only re-queued once")
        vm.next()
        XCTAssertEqual(vm.phase, .finished)
        XCTAssertEqual(vm.accuracy, 0)
    }

    func testOutOfHearts() {
        let vm = LessonSessionViewModel(lessonTitle: "t", exercises: [choice()])
        vm.onMistake = { false }
        vm.select("b")
        vm.check()
        XCTAssertEqual(vm.phase, .outOfHearts)
    }

    func testDebugFinish() {
        let perfect = LessonSessionViewModel(lessonTitle: "t", exercises: [choice(), choice()])
        perfect.select("b")
        perfect.check()
        perfect.debugFinish(perfect: true)
        XCTAssertEqual(perfect.phase, .finished)
        XCTAssertEqual(perfect.accuracy, 1)
        XCTAssertEqual(perfect.progress, 1)

        let withMistake = LessonSessionViewModel(lessonTitle: "t", exercises: [choice()])
        withMistake.debugFinish(perfect: false)
        XCTAssertEqual(withMistake.phase, .finished)
        XCTAssertLessThan(withMistake.accuracy, 1)
    }
}

@MainActor
final class ProgressServiceTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return c
    }

    private func key(_ daysAgo: Int, from today: Date) -> String {
        ProgressService.dayKey(for: calendar.date(byAdding: .day, value: -daysAgo, to: today)!, calendar: calendar)
    }

    func testStreakCountsConsecutiveDays() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let keys: Set<String> = [key(0, from: today), key(1, from: today), key(2, from: today), key(4, from: today)]
        XCTAssertEqual(ProgressService.streak(activeDayKeys: keys, today: today, calendar: calendar), 3)
    }

    func testStreakSurvivesUntilEndOfToday() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let keys: Set<String> = [key(1, from: today), key(2, from: today)]
        XCTAssertEqual(ProgressService.streak(activeDayKeys: keys, today: today, calendar: calendar), 2)
    }

    func testStreakBrokenAfterMissedDay() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let keys: Set<String> = [key(2, from: today), key(3, from: today)]
        XCTAssertEqual(ProgressService.streak(activeDayKeys: keys, today: today, calendar: calendar), 0)
    }

    func testFrozenDayKeepsStreakWithoutAddingToIt() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let active: Set<String> = [key(0, from: today), key(2, from: today), key(3, from: today)]
        let frozen: Set<String> = [key(1, from: today)]
        XCTAssertEqual(ProgressService.streak(activeDayKeys: active, frozenDayKeys: frozen, today: today, calendar: calendar), 3)
        XCTAssertEqual(ProgressService.streak(activeDayKeys: active, today: today, calendar: calendar), 1)
    }

    func testFrozenYesterdayKeepsStreakUntilEndOfToday() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let active: Set<String> = [key(2, from: today), key(3, from: today)]
        let frozen: Set<String> = [key(1, from: today)]
        XCTAssertEqual(ProgressService.streak(activeDayKeys: active, frozenDayKeys: frozen, today: today, calendar: calendar), 2)
    }

    func testPerfectBonus() {
        XCTAssertEqual(ProgressService.lessonXP(base: 10, accuracy: 1), 15)
        XCTAssertEqual(ProgressService.lessonXP(base: 10, accuracy: 0.8), 10)
    }
}

@MainActor
final class LocalizationTests: XCTestCase {
    /// UI languages and learnable courses must be the same set.
    func testUILanguagesMatchCourses() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        ContentImporter(context: container.mainContext).importBundledCourses()
        let courseIds = Set(try container.mainContext.fetch(FetchDescriptor<Course>()).map(\.remoteId))
        XCTAssertEqual(Set(LanguageCode.allCases.map(\.courseId)), courseIds)
    }

    func testEveryUILanguageHasStringsFile() {
        for code in LanguageCode.allCases {
            XCTAssertNotNil(Bundle.main.url(forResource: code.getLanguage().fileName, withExtension: "json"), "\(code)")
        }
    }

    /// Every strings file must have exactly the same keys as English (no missing or stale keys).
    func testStringsFilesHaveSameKeysAsEnglish() throws {
        func keys(_ fileName: String) throws -> Set<String> {
            let url = try XCTUnwrap(Bundle.main.url(forResource: fileName, withExtension: "json"), fileName)
            let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let data = try XCTUnwrap(json["data"] as? [String: String], fileName)
            return Set(data.keys)
        }
        let english = try keys(LanguageCode.eng.getLanguage().fileName)
        for code in LanguageCode.allCases {
            let fileName = code.getLanguage().fileName
            let other = try keys(fileName)
            XCTAssertEqual(english.subtracting(other).sorted(), [], "missing in \(fileName)")
            XCTAssertEqual(other.subtracting(english).sorted(), [], "extra in \(fileName)")
        }
    }

    func testSlowSpeechIsMuchSlower() {
        let normal = SpeechService.rate(slow: false)
        let slow = SpeechService.rate(slow: true)
        XCTAssertLessThanOrEqual(slow, normal * 0.5, "Tortoise speed should be at most half the normal speed")
        XCTAssertGreaterThanOrEqual(slow, AVSpeechUtteranceMinimumSpeechRate)
    }

    func testLocalizedTextFallsBackToEnglish() {
        let text = LocalizedText(en: "hello", ja: "こんにちは")
        XCTAssertEqual(text.resolved(for: LanguageCode.ja.rawValue), "こんにちは")
        XCTAssertEqual(text.resolved(for: LanguageCode.ko.rawValue), "hello")
    }
}

@MainActor
final class ContentImporterTests: XCTestCase {
    /// Unit tests are hosted in the app, so `Bundle.main` contains Resources/Content.
    func testBundledCoursesImportAndKeepProgressOnReimport() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let importer = ContentImporter(context: context)
        importer.importBundledCourses()

        let courses = try context.fetch(FetchDescriptor<Course>())
        XCTAssertEqual(courses.count, 6)
        // Expected sizes come from the bundled JSON, so adding content doesn't break the test.
        let expected = try Self.bundledCounts("course_ja")
        let totalWords = try LanguageCode.allCases.reduce(0) { $0 + (try Self.bundledCounts("course_\($1.courseId)").words) }
        let japanese = try XCTUnwrap(courses.first { $0.remoteId == "ja" })
        XCTAssertEqual(japanese.orderedLessons.count, expected.lessons)
        XCTAssertEqual(japanese.allItems.count, expected.words)

        // Every word has an example sentence, split into chunks that rebuild it (sentence builder).
        for item in japanese.allItems {
            let example = try XCTUnwrap(item.example, item.remoteId)
            let tokens = try XCTUnwrap(item.exampleTokens, item.remoteId)
            XCTAssertGreaterThanOrEqual(tokens.count, 2, item.remoteId)
            XCTAssertEqual(tokens.joined(), example, item.remoteId)
        }

        // Number lessons explain how numbers are built with a tip (Korean: native vs Sino-Korean).
        let korean = try XCTUnwrap(courses.first { $0.remoteId == "ko" })
        let numbers = try XCTUnwrap(korean.orderedLessons.first { $0.remoteId == "ko-u2-l1" })
        XCTAssertFalse(try XCTUnwrap(numbers.tip).en.isEmpty)
        XCTAssertNotNil(numbers.tip?.vi)
        XCTAssertEqual(numbers.sortedItems.count, 21, "0–10 plus 11, 15, 20, 21, 45, 99, 100, 300, 1,000, 10,000")
        XCTAssertNil(korean.orderedLessons.first { $0.remoteId == "ko-u2-l2" }?.tip, "Food & drink has no tip")

        // Vietnamese is spaced by syllable: multi-syllable words must stay in one chunk.
        let vietnamese = try XCTUnwrap(courses.first { $0.remoteId == "vi" })
        let airport = try XCTUnwrap(vietnamese.allItems.first { $0.remoteId == "vi-0081" })
        XCTAssertEqual(airport.exampleTokens, ["Tôi", "đi", "taxi", "đến", "sân bay."])
        for item in vietnamese.allItems {
            XCTAssertEqual(item.exampleTokens?.joined(separator: " "), item.example, item.remoteId)
        }

        // Learn a word, then re-import → SRS state must be kept, no duplicates.
        let word = try XCTUnwrap(japanese.allItems.first)
        word.srsState = SRSScheduler().introduce()
        importer.importBundledCourses()
        XCTAssertEqual(try context.fetch(FetchDescriptor<VocabItem>()).count, totalWords)
        XCTAssertTrue(word.isLearned)

        // Content update (higher version): text changes, a learned word moves to another
        // lesson, another word is removed → progress kept, removed word deleted.
        let url = try XCTUnwrap(Bundle.main.url(forResource: "course_ja", withExtension: "json"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["version"] = (json["version"] as? Int ?? 0) + 1
        var units = try XCTUnwrap(json["units"] as? [[String: Any]])
        var lessons = try XCTUnwrap(units[0]["lessons"] as? [[String: Any]])
        var firstItems = try XCTUnwrap(lessons[0]["items"] as? [[String: Any]])
        var secondItems = try XCTUnwrap(lessons[1]["items"] as? [[String: Any]])
        var moved = firstItems.removeFirst()          // the learned word
        moved["term"] = "こんにちは!"
        secondItems.append(moved)
        let removed = firstItems.removeLast()
        let removedId = try XCTUnwrap(removed["id"] as? String)
        lessons[0]["items"] = firstItems
        lessons[1]["items"] = secondItems
        units[0]["lessons"] = lessons
        json["units"] = units
        try importer.importCourse(from: JSONSerialization.data(withJSONObject: json), order: 2)
        try context.save()

        XCTAssertEqual(word.term, "こんにちは!")
        XCTAssertTrue(word.isLearned, "Moving a word to another lesson keeps its SRS state")
        XCTAssertEqual(word.lesson?.remoteId, lessons[1]["id"] as? String)
        XCTAssertEqual(try context.fetch(FetchDescriptor<VocabItem>()).count, totalWords - 1)
        let removedLeft = try context.fetch(FetchDescriptor<VocabItem>(predicate: #Predicate { $0.remoteId == removedId }))
        XCTAssertTrue(removedLeft.isEmpty, "Words removed from the content are deleted")
    }

    /// Lesson and word counts of a bundled course file.
    private static func bundledCounts(_ fileName: String) throws -> (lessons: Int, words: Int) {
        let url = try XCTUnwrap(Bundle.main.url(forResource: fileName, withExtension: "json"), fileName)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let lessons = (json["units"] as? [[String: Any]] ?? []).flatMap { $0["lessons"] as? [[String: Any]] ?? [] }
        let words = lessons.reduce(0) { $0 + (($1["items"] as? [Any])?.count ?? 0) }
        return (lessons.count, words)
    }
}

@MainActor
final class StreakFreezeTests: XCTestCase {
    private let suiteName = "StreakFreezeTests"
    private var today: Date { Date(timeIntervalSince1970: 1_800_000_000) }
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return c
    }

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: today))!
    }

    private func key(_ daysAgo: Int) -> String {
        ProgressService.dayKey(for: day(daysAgo), calendar: calendar)
    }

    private func makeGamification() throws -> GamificationManager {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return GamificationManager(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: Gap

    func testNoGapWhenYesterdayWasActive() {
        XCTAssertNil(StreakFreezeService.gap(activeDayKeys: [key(1), key(2)], frozenDayKeys: [], today: today, calendar: calendar))
    }

    func testNoGapWithoutAnyStreak() {
        XCTAssertNil(StreakFreezeService.gap(activeDayKeys: [], frozenDayKeys: [], today: today, calendar: calendar))
    }

    func testGapListsMissedDaysOldestFirst() throws {
        let gap = try XCTUnwrap(StreakFreezeService.gap(activeDayKeys: [key(0), key(3)], frozenDayKeys: [],
                                                        today: today, calendar: calendar))
        XCTAssertEqual(gap.lastKeptDayKey, key(3))
        XCTAssertEqual(gap.missedDays, [day(2), day(1)])
    }

    func testFrozenDayCountsAsKept() throws {
        let gap = try XCTUnwrap(StreakFreezeService.gap(activeDayKeys: [key(3)], frozenDayKeys: [key(2)],
                                                        today: today, calendar: calendar))
        XCTAssertEqual(gap.lastKeptDayKey, key(2))
        XCTAssertEqual(gap.missedDays, [day(1)])
    }

    func testCanCover() {
        let oneDay = StreakFreezeService.Gap(lastKeptDayKey: "k", missedDays: [day(1)])
        let threeDays = StreakFreezeService.Gap(lastKeptDayKey: "k", missedDays: [day(3), day(2), day(1)])
        XCTAssertTrue(StreakFreezeService.canCover(oneDay, availableFreezes: 1, lostAfterDayKey: nil))
        XCTAssertFalse(StreakFreezeService.canCover(oneDay, availableFreezes: 0, lostAfterDayKey: nil))
        XCTAssertFalse(StreakFreezeService.canCover(oneDay, availableFreezes: 2, lostAfterDayKey: "k"), "A lost streak stays lost")
        XCTAssertFalse(StreakFreezeService.canCover(threeDays, availableFreezes: 99, lostAfterDayKey: nil),
                       "Gaps longer than maxStreakFreezes are never covered")
    }

    // MARK: Buying

    func testBuyStreakFreezeSpendsXP() throws {
        let gamification = try makeGamification()
        XCTAssertEqual(gamification.buyStreakFreeze(totalXP: 40), .notEnoughXP)
        XCTAssertEqual(gamification.buyStreakFreeze(totalXP: 120), .bought)
        XCTAssertEqual(gamification.streakFreezes, 1)
        XCTAssertEqual(gamification.xpBalance(totalXP: 120), 70)
        XCTAssertEqual(gamification.buyStreakFreeze(totalXP: 120), .bought)
        XCTAssertEqual(gamification.buyStreakFreeze(totalXP: 1_000), .alreadyFull)
        XCTAssertEqual(gamification.xpBalance(totalXP: 120), 20)
        XCTAssertEqual(GamificationManager(defaults: try XCTUnwrap(UserDefaults(suiteName: suiteName))).streakFreezes, 2,
                       "Freezes persist")
    }

    func testPlusIsAlwaysFullyEquipped() throws {
        let gamification = try makeGamification()
        XCTAssertEqual(gamification.availableStreakFreezes(isPremium: true), GamificationManager.maxStreakFreezes)
        gamification.useStreakFreezes(1, isPremium: true)
        XCTAssertEqual(gamification.streakFreezes, 0)
    }

    // MARK: Applying

    private func insertActivity(_ daysAgo: Int, xp: Int = 10, in context: ModelContext) {
        let activity = DailyActivity(dayKey: key(daysAgo), date: day(daysAgo))
        activity.xp = xp
        context.insert(activity)
    }

    func testApplyFreezesMissedDayAndKeepsStreak() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        [2, 3, 4].forEach { insertActivity($0, in: context) }
        let gamification = try makeGamification()
        gamification.debugSetStreakFreezes(2)

        let frozen = StreakFreezeService.applyIfNeeded(in: context, gamification: gamification, isPremium: false,
                                                       now: today, calendar: calendar)
        XCTAssertEqual(frozen, 1)
        XCTAssertEqual(gamification.streakFreezes, 1)
        let activities = ProgressService.allActivities(in: context)
        XCTAssertEqual(ProgressService.frozenDayKeys(from: activities), [key(1)])
        XCTAssertEqual(ProgressService.streak(from: activities, today: today, calendar: calendar), 3)

        // Running again changes nothing.
        XCTAssertEqual(StreakFreezeService.applyIfNeeded(in: context, gamification: gamification, isPremium: false,
                                                         now: today, calendar: calendar), 0)
        XCTAssertEqual(gamification.streakFreezes, 1)
    }

    func testStreakLostWhenNotEnoughFreezes() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        [3, 4].forEach { insertActivity($0, in: context) }
        let gamification = try makeGamification()
        gamification.debugSetStreakFreezes(1)

        XCTAssertEqual(StreakFreezeService.applyIfNeeded(in: context, gamification: gamification, isPremium: false,
                                                         now: today, calendar: calendar), 0)
        XCTAssertEqual(gamification.streakFreezes, 1, "Freezes are kept when they can't save the streak")
        XCTAssertEqual(gamification.streakLostAfterDayKey, key(3))

        // Buying more freezes afterwards doesn't bring the lost streak back.
        XCTAssertEqual(gamification.buyStreakFreeze(totalXP: 1_000), .bought)
        XCTAssertEqual(StreakFreezeService.applyIfNeeded(in: context, gamification: gamification, isPremium: false,
                                                         now: today, calendar: calendar), 0)
    }

    func testPlusFreezesWithoutUsingInventory() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        [3, 4].forEach { insertActivity($0, in: context) }
        let gamification = try makeGamification()

        XCTAssertEqual(StreakFreezeService.applyIfNeeded(in: context, gamification: gamification, isPremium: true,
                                                         now: today, calendar: calendar), 2)
        XCTAssertEqual(gamification.streakFreezes, 0)
        XCTAssertEqual(ProgressService.streak(from: ProgressService.allActivities(in: context), today: today, calendar: calendar), 2)
    }
}

@MainActor
final class DailyQuestTests: XCTestCase {
    private var now: Date { Date(timeIntervalSince1970: 1_800_000_000) }

    func testPlanAlwaysHasEarnXPAndThreeDifferentQuests() {
        for day in 1...28 {
            let key = String(format: "2026-10-%02ld", day)
            let kinds = DailyQuestService.plan(dayKey: key, hasLearnedWords: true)
            XCTAssertEqual(kinds.count, DailyQuestService.questsPerDay)
            XCTAssertEqual(kinds.first, .earnXP)
            XCTAssertEqual(Set(kinds).count, kinds.count)
        }
    }

    func testPlanIsStableForADay() {
        XCTAssertEqual(DailyQuestService.plan(dayKey: "2026-10-03", hasLearnedWords: true),
                       DailyQuestService.plan(dayKey: "2026-10-03", hasLearnedWords: true))
        XCTAssertEqual(DailyQuestService.stableHash("2026-10-03"), DailyQuestService.stableHash("2026-10-03"))
    }

    func testPlanVariesAcrossDays() {
        let plans = Set((1...28).map { DailyQuestService.plan(dayKey: String(format: "2026-10-%02ld", $0),
                                                               hasLearnedWords: true) })
        XCTAssertGreaterThan(plans.count, 1)
    }

    func testNoReviewQuestWithoutLearnedWords() {
        for day in 1...28 {
            let kinds = DailyQuestService.plan(dayKey: String(format: "2026-10-%02ld", day), hasLearnedWords: false)
            XCTAssertFalse(kinds.contains(.reviewCards))
        }
    }

    func testEarnXPTargetIsTheDailyGoal() {
        XCTAssertEqual(DailyQuestService.quest(.earnXP, dailyGoalXP: 30).target, 30)
    }

    func testProgressReadsTheDayCounters() {
        _ = PersistenceController.makeContainer(inMemory: true)
        let activity = DailyActivity(dayKey: "k", date: now)
        activity.xp = 12
        activity.lessonsCompleted = 1
        activity.reviewsDone = 20
        activity.perfectLessons = 1
        XCTAssertEqual(DailyQuestService.progress(of: DailyQuestService.quest(.earnXP, dailyGoalXP: 20), in: activity), 12)
        XCTAssertEqual(DailyQuestService.progress(of: DailyQuestService.quest(.completeLessons, dailyGoalXP: 20), in: activity), 1)
        XCTAssertTrue(DailyQuestService.isComplete(DailyQuestService.quest(.reviewCards, dailyGoalXP: 20), in: activity))
        XCTAssertTrue(DailyQuestService.isComplete(DailyQuestService.quest(.perfectLesson, dailyGoalXP: 20), in: activity))
        XCTAssertEqual(DailyQuestService.progress(of: DailyQuestService.quest(.earnXP, dailyGoalXP: 20), in: nil), 0)
    }

    func testClaimGivesEachRewardOnceAndChainsIntoEarnXP() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let activity = DailyQuestService.ensureTodayQuests(in: context, now: now)
        activity.questKinds = [DailyQuest.Kind.earnXP, .completeLessons, .perfectLesson].map(\.rawValue)

        // 2 lessons, one perfect: 15 + 15 XP of rewards push 5 XP over the 20 XP goal.
        ProgressService.record(xp: 5, lessons: 2, perfect: 1, in: context, now: now)
        let claimed = DailyQuestService.claimCompleted(in: context, dailyGoalXP: 20, now: now)
        XCTAssertEqual(Set(claimed.map(\.kind)), [.earnXP, .completeLessons, .perfectLesson])
        XCTAssertEqual(activity.xp, 5 + 15 + 15 + 10)

        XCTAssertTrue(DailyQuestService.claimCompleted(in: context, dailyGoalXP: 20, now: now).isEmpty)
        XCTAssertEqual(activity.xp, 45)
    }

    func testTodayQuestsArePickedOnce() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let first = DailyQuestService.ensureTodayQuests(in: context, now: now)
        XCTAssertFalse(first.questKinds?.contains(DailyQuest.Kind.reviewCards.rawValue) ?? true,
                       "No learned words yet → no review quest")
        let kinds = first.questKinds
        let item = VocabItem(remoteId: "w", courseId: "en")
        context.insert(item)
        item.srsDue = now
        XCTAssertEqual(DailyQuestService.ensureTodayQuests(in: context, now: now).questKinds, kinds)
    }

    func testShiftPicksAnotherSetForTheSameDay() {
        let base = DailyQuestService.plan(dayKey: "2026-10-03", hasLearnedWords: true)
        let next = DailyQuestService.plan(dayKey: "2026-10-03", hasLearnedWords: true, shift: 1)
        XCTAssertNotEqual(base, next)
        XCTAssertEqual(next.first, .earnXP)
        XCTAssertEqual(DailyQuestService.plan(dayKey: "2026-10-03", hasLearnedWords: true, shift: 3), base,
                       "Shifting by the number of candidates wraps around")
    }

    func testStartTodayOverClearsTodayOnly() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let yesterday = now.addingTimeInterval(-86_400)
        ProgressService.record(xp: 30, lessons: 2, in: context, now: yesterday)
        ProgressService.record(xp: 40, lessons: 2, reviews: 15, perfect: 1, in: context, now: now)
        DailyQuestService.claimCompleted(in: context, dailyGoalXP: 20, now: now)

        DebugActions.startTodayOver(in: context, now: now)
        let today = ProgressService.activity(on: now, in: context)
        XCTAssertEqual(today.xp, 0)
        XCTAssertEqual(today.lessonsCompleted, 0)
        XCTAssertEqual(today.perfectLessons, 0)
        XCTAssertNil(today.claimedQuests)
        XCTAssertNotNil(today.questKinds)
        XCTAssertEqual(ProgressService.activity(on: yesterday, in: context).xp, 30)
    }

    func testNextQuestSetKeepsRewards() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        ProgressService.record(xp: 25, in: context, now: now)
        DailyQuestService.claimCompleted(in: context, dailyGoalXP: 20, now: now)
        let before = ProgressService.activity(on: now, in: context)
        let kinds = before.questKinds

        let next = DebugActions.nextQuestSet(in: context, now: now)
        XCTAssertNotEqual(next.map(\.rawValue), kinds)
        XCTAssertTrue(DailyQuestService.claimCompleted(in: context, dailyGoalXP: 20, now: now).isEmpty,
                      "Earn XP was already rewarded")
    }

    func testResetEverythingDeletesActivity() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        ProgressService.record(xp: 30, lessons: 1, in: context, now: now)
        try? context.save()
        DebugActions.resetEverything(in: context)
        XCTAssertTrue(ProgressService.allActivities(in: context).isEmpty)
    }
}

@MainActor
final class UnitCheckpointTests: XCTestCase {
    private var now: Date { Date(timeIntervalSince1970: 1_800_000_000) }

    /// 2 units × 2 lessons × 2 words.
    private func makeCourse(in context: ModelContext) -> Course {
        let course = Course(remoteId: "en")
        context.insert(course)
        for u in 0..<2 {
            let unit = CourseUnit(remoteId: "u\(u)")
            unit.order = u
            context.insert(unit)
            unit.course = course
            for l in 0..<2 {
                let lesson = Lesson(remoteId: "u\(u)-l\(l)")
                lesson.order = l
                context.insert(lesson)
                lesson.unit = unit
                for w in 0..<2 {
                    let item = VocabItem(remoteId: "u\(u)-l\(l)-w\(w)", courseId: "en")
                    item.order = w
                    context.insert(item)
                    item.lesson = lesson
                }
            }
        }
        try? context.save()
        return course
    }

    func testNextUnitWaitsForTheCheckpoint() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let course = makeCourse(in: container.mainContext)
        let first = course.sortedUnits[0], second = course.sortedUnits[1]
        XCTAssertFalse(first.isCheckpointUnlocked)

        first.sortedLessons.forEach { $0.isCompleted = true }
        XCTAssertTrue(first.isCheckpointUnlocked)
        let nextLesson = second.sortedLessons[0]
        XCTAssertFalse(course.isUnlocked(nextLesson))
        XCTAssertTrue(course.isWaitingForCheckpoint(nextLesson))

        first.checkpointPassed = true
        XCTAssertTrue(course.isUnlocked(nextLesson))
        XCTAssertFalse(course.isUnlocked(second.sortedLessons[1]), "Lessons inside a unit still unlock in order")
    }

    func testCompletedLessonsStayUnlocked() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let course = makeCourse(in: container.mainContext)
        course.orderedLessons.prefix(3).forEach { $0.isCompleted = true }
        // Progress made before checkpoints existed is not locked away.
        XCTAssertTrue(course.isUnlocked(course.sortedUnits[1].sortedLessons[0]))
        XCTAssertTrue(course.isUnlocked(course.sortedUnits[1].sortedLessons[1]))
    }

    func testPassThreshold() {
        XCTAssertTrue(UnitCheckpointService.isPassing(accuracy: 0.8))
        XCTAssertTrue(UnitCheckpointService.isPassing(accuracy: 12.0 / 15.0))
        XCTAssertFalse(UnitCheckpointService.isPassing(accuracy: 0.79))
    }

    func testPickWordsMixesWeakAndRandom() {
        var rng = SeededGenerator(seed: 7)
        let words = (0..<20).map { PracticeService.Candidate(id: "w\($0)", mistakes: $0 < 3 ? 2 : 0, interval: 10) }
        let picked = UnitCheckpointService.pickWords(words, count: 10, using: &rng)
        XCTAssertEqual(picked.count, 10)
        XCTAssertEqual(Set(picked).count, 10)
        XCTAssertTrue(Set(["w0", "w1", "w2"]).isSubset(of: Set(picked)), "Weak words are always tested")

        let few = Array(words.prefix(6))
        XCTAssertEqual(Set(UnitCheckpointService.pickWords(few, count: 10, using: &rng)), Set(few.map(\.id)))
    }

    func testCheckpointHasNoEasyQuestions() {
        var rng = SeededGenerator(seed: 1)
        let items = (0..<6).map {
            StudyItem(id: "w\($0)", term: "term\($0)", reading: nil, meaning: "meaning\($0)",
                      example: nil, exampleMeaning: nil, speechLocale: "en-US")
        }
        let exercises = ExerciseGenerator().makeCheckpoint(items: items, distractorPool: [], intro: "intro", using: &rng)
        XCTAssertEqual(exercises.first, .tip("intro"))
        XCTAssertEqual(exercises.count, items.count + 1)
        for exercise in exercises.dropFirst() {
            switch exercise {
            case .tip, .introduce, .chooseMeaning, .matchPairs: XCTFail("Unexpected \(exercise)")
            default: break
            }
        }
    }

    func testPassingUnlocksOnceAndGivesXP() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = makeCourse(in: context)
        let unit = course.sortedUnits[0]

        let failed = UnitCheckpointService.complete(unit: unit, items: unit.allItems, accuracy: 0.6,
                                                    dailyGoalXP: 100, in: context, now: now)
        XCTAssertEqual(failed.checkpoint?.passed, false)
        XCTAssertEqual(failed.xpEarned, 0)
        XCTAssertFalse(unit.checkpointPassed)
        XCTAssertEqual(unit.checkpointBestAccuracy, 0.6, accuracy: 0.001)

        let passed = UnitCheckpointService.complete(unit: unit, items: unit.allItems, accuracy: 0.9,
                                                    dailyGoalXP: 100, in: context, now: now)
        XCTAssertEqual(passed.checkpoint?.passed, true)
        XCTAssertEqual(passed.checkpoint?.unlockedNextUnit, true)
        XCTAssertEqual(passed.xpEarned, UnitCheckpointService.xpReward)
        XCTAssertTrue(unit.checkpointPassed)

        let again = UnitCheckpointService.complete(unit: unit, items: unit.allItems, accuracy: 1,
                                                   dailyGoalXP: 100, in: context, now: now)
        XCTAssertEqual(again.checkpoint?.unlockedNextUnit, false)
        XCTAssertEqual(again.xpEarned, UnitCheckpointService.xpReward + 5)
    }

    func testResetProgressResetsCheckpoints() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = makeCourse(in: context)
        course.sortedUnits[0].checkpointPassed = true
        LessonCompletionService.resetProgress(of: course, in: context)
        XCTAssertFalse(course.sortedUnits[0].checkpointPassed)
    }
}


@MainActor
final class NotificationPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return c
    }

    /// Today at hh:mm (Asia/Ho_Chi_Minh).
    private func today(_ hour: Int, _ minute: Int = 0) -> Date {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    private func input(now: Date, streak: Int = 0, studiedToday: Bool = false, due: [Date] = []) -> NotificationPlanner.Input {
        NotificationPlanner.Input(now: now, calendar: calendar, reminderHour: 19, reminderMinute: 30,
                                  streak: streak, studiedToday: studiedToday, dueDates: due)
    }

    func testOneReminderPerDayAhead() {
        let plan = NotificationPlanner.plan(input(now: today(8)))
        XCTAssertEqual(plan.count, NotificationPlanner.daysAhead)
        XCTAssertTrue(plan.allSatisfy { $0.kind == .reminder })
        XCTAssertEqual(plan.first?.date, today(19, 30))
        XCTAssertEqual(Set(plan.map(\.id)).count, plan.count, "Ids are unique")
    }

    func testNoReminderTodayAfterStudying() {
        let plan = NotificationPlanner.plan(input(now: today(8), studiedToday: true))
        XCTAssertFalse(plan.contains { calendar.isDate($0.date, inSameDayAs: today(8)) })
    }

    func testPastReminderTimeIsSkipped() {
        let plan = NotificationPlanner.plan(input(now: today(20)))
        XCTAssertFalse(plan.contains { $0.kind == .reminder && calendar.isDate($0.date, inSameDayAs: today(20)) })
    }

    func testStreakAtRiskTonight() throws {
        let plan = NotificationPlanner.plan(input(now: today(8), streak: 5))
        let risk = try XCTUnwrap(plan.first { $0.kind == .streakAtRisk(5) })
        XCTAssertEqual(risk.date, today(NotificationPlanner.streakRiskHour))
        XCTAssertTrue(plan.contains { $0.date == today(19, 30) }, "19:30 is over an hour before 21:00 → both")
    }

    func testReminderTooCloseToStreakWarningIsDropped() {
        var late = input(now: today(8), streak: 5)
        late.reminderHour = 20
        late.reminderMinute = 30
        let todays = NotificationPlanner.plan(late).filter { calendar.isDate($0.date, inSameDayAs: today(8)) }
        XCTAssertEqual(todays.map(\.kind), [.streakAtRisk(5)])
    }

    func testStudiedTodayWarnsTomorrowOnly() {
        let plan = NotificationPlanner.plan(input(now: today(8), streak: 6, studiedToday: true))
        let risks = plan.filter { if case .streakAtRisk = $0.kind { return true } else { return false } }
        XCTAssertEqual(risks.count, 1)
        XCTAssertEqual(risks.first?.kind, .streakAtRisk(6))
        XCTAssertEqual(risks.first?.date, calendar.date(byAdding: .day, value: 1, to: today(21)))
    }

    func testDueCardsChangeTheReminder() {
        let due = Array(repeating: today(10), count: 6) + [today(23)]
        let plan = NotificationPlanner.plan(input(now: today(8), due: due))
        XCTAssertEqual(plan.first?.kind, .dueCards(6), "Only cards due by 19:30 count")
        XCTAssertEqual(plan[1].kind, .dueCards(7))
    }

    func testUsualStudyTime() {
        let now = today(22)
        let times = [-1, -2, -3, -4].map { calendar.date(byAdding: .day, value: $0, to: today(20, 40))! }
            + [calendar.date(byAdding: .day, value: -5, to: today(7, 10))!]
        let usual = NotificationPlanner.usualStudyTime(firstActiveTimes: times, now: now, calendar: calendar)
        XCTAssertEqual(usual?.hour, 20)
        XCTAssertEqual(usual?.minute, 30, "Median 20:40 rounded down to 15 minutes")

        XCTAssertNil(NotificationPlanner.usualStudyTime(firstActiveTimes: Array(times.prefix(2)), now: now, calendar: calendar),
                     "Needs a few days of history")
        let old = times.map { calendar.date(byAdding: .day, value: -30, to: $0)! }
        XCTAssertNil(NotificationPlanner.usualStudyTime(firstActiveTimes: old, now: now, calendar: calendar))
    }

    func testUsualStudyTimeStaysInTheWindow() {
        let now = today(22)
        let late = [-1, -2, -3].map { calendar.date(byAdding: .day, value: $0, to: today(23, 50))! }
        let usual = NotificationPlanner.usualStudyTime(firstActiveTimes: late, now: now, calendar: calendar)
        XCTAssertEqual(usual?.hour, NotificationPlanner.latestHour)
        XCTAssertEqual(usual?.minute, 0)
    }

    func testRecordStoresFirstActivityTime() {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        ProgressService.record(xp: 10, in: context, now: morning)
        ProgressService.record(xp: 10, in: context, now: morning.addingTimeInterval(3_600))
        XCTAssertEqual(ProgressService.activity(on: morning, in: context).firstActiveAt, morning)
    }
}

@MainActor
final class AchievementTests: XCTestCase {
    private let suiteName = "AchievementTests"

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testLongestStreakKeepsTheBestChain() {
        let active: Set<String> = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04",
                                   "2026-09-10", "2026-09-11"]
        XCTAssertEqual(AchievementService.longestStreak(activeDayKeys: active, frozenDayKeys: []), 4)
    }

    func testFrozenDayBridgesTheChainWithoutCounting() {
        let active: Set<String> = ["2026-09-01", "2026-09-02", "2026-09-04"]
        XCTAssertEqual(AchievementService.longestStreak(activeDayKeys: active, frozenDayKeys: ["2026-09-03"]), 3)
        XCTAssertEqual(AchievementService.longestStreak(activeDayKeys: active, frozenDayKeys: []), 2)
        XCTAssertEqual(AchievementService.longestStreak(activeDayKeys: [], frozenDayKeys: []), 0)
    }

    func testChainAcrossMonthEnd() {
        XCTAssertEqual(AchievementService.longestStreak(activeDayKeys: ["2026-09-30", "2026-10-01"], frozenDayKeys: []), 2)
    }

    func testNewlyReachedSkipsUnlockedOnes() {
        let stats = AchievementStats(bestStreak: 7, lessonsCompleted: 1)
        let ids = Set(AchievementService.newlyReached(stats, unlockedIds: ["streak3"]).map(\.id))
        XCTAssertEqual(ids, ["first_lesson", "streak7"])
    }

    func testProgress() throws {
        let words = try XCTUnwrap(Achievement.all.first { $0.id == "words50" })
        let progress = words.progress(AchievementStats(wordsLearned: 20))
        XCTAssertEqual(progress.value, 20)
        XCTAssertEqual(progress.target, 50)
        XCTAssertEqual(Set(Achievement.all.map(\.id)).count, Achievement.all.count, "Ids are unique")
    }

    func testQuestDaysCountOnlyFullyClaimedDays() {
        _ = PersistenceController.makeContainer(inMemory: true)
        let done = DailyActivity(dayKey: "2026-09-01", date: .now)
        done.questKinds = ["earn_xp", "complete_lessons", "perfect_lesson"]
        done.claimedQuests = ["complete_lessons", "earn_xp", "perfect_lesson"]
        let partial = DailyActivity(dayKey: "2026-09-02", date: .now)
        partial.questKinds = ["earn_xp", "complete_lessons", "perfect_lesson"]
        partial.claimedQuests = ["earn_xp"]
        let stats = AchievementService.stats(activities: [done, partial], wordsLearned: 0, lessonsCompleted: 0,
                                             perfectLessonsFromHistory: 0, checkpointsPassed: 0)
        XCTAssertEqual(stats.questDaysCompleted, 1)
    }

    func testCheckNewUnlocksOnceAndKeepsIt() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        ProgressService.record(xp: 600, lessons: 1, perfect: 1, in: context)
        try context.save()

        let first = AchievementService.checkNew(in: context, defaults: defaults)
        XCTAssertTrue(Set(first.map(\.id)).isSuperset(of: ["perfect", "xp500"]))
        XCTAssertTrue(AchievementService.checkNew(in: context, defaults: defaults).isEmpty, "Unlocked only once")
        XCTAssertNotNil(AchievementService.unlockedDates(defaults: defaults)["xp500"])
    }
}

@MainActor
final class RemoteContentTests: XCTestCase {
    private func entry(_ id: String, _ version: Int, sha: String = "") -> ContentManifest.Entry {
        ContentManifest.Entry(id: id, version: version, file: "course_\(id).json", sha256: sha)
    }

    private func manifest(_ courses: [ContentManifest.Entry], schema: Int = 1, minApp: String = "1.0") -> ContentManifest {
        ContentManifest(schema: schema, minAppVersion: minApp, courses: courses)
    }

    func testOnlyNewerCoursesAreDownloaded() {
        let m = manifest([entry("en", 9), entry("ja", 7), entry("fr", 1)])
        let ids = RemoteContentService.coursesToDownload(m, installed: ["en": 8, "ja": 7], appVersion: "1.0").map(\.id)
        XCTAssertEqual(ids, ["en", "fr"], "ja is up to date; a new course is downloaded too")
    }

    func testContentForANewerAppIsIgnored() {
        let m = manifest([entry("en", 9)], minApp: "1.2")
        XCTAssertTrue(RemoteContentService.coursesToDownload(m, installed: [:], appVersion: "1.1.9").isEmpty)
        XCTAssertEqual(RemoteContentService.coursesToDownload(m, installed: [:], appVersion: "1.2").count, 1)
        XCTAssertTrue(RemoteContentService.coursesToDownload(manifest([entry("en", 9)], schema: 2),
                                                             installed: [:], appVersion: "9.0").isEmpty)
    }

    func testVersionComparison() {
        XCTAssertTrue(RemoteContentService.isVersion("1.10", atLeast: "1.9"))
        XCTAssertTrue(RemoteContentService.isVersion("1.0", atLeast: "1"))
        XCTAssertTrue(RemoteContentService.isVersion("2.0.1", atLeast: "2.0"))
        XCTAssertFalse(RemoteContentService.isVersion("1.2", atLeast: "1.10"))
    }

    func testManifestDecodes() throws {
        let json = """
        {"schema": 1, "minAppVersion": "1.0", "generatedAt": "2026-10-03T00:00:00Z",
         "courses": [{"id": "en", "version": 9, "file": "course_en.json", "sha256": "abc"}]}
        """
        let m = try JSONDecoder().decode(ContentManifest.self, from: Data(json.utf8))
        XCTAssertEqual(m.courses.first, entry("en", 9, sha: "abc"))
        XCTAssertEqual(RemoteContentService.manifestURL(channel: .staging).absoluteString,
                       "https://haonguyendev.github.io/LanguageApp-content/v1/staging/manifest.json")
    }

    /// Unit tests are hosted in the app, so the bundled course JSON is available.
    private func bundledCourse(_ id: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "course_\(id)", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testDownloadedFileMustMatchTheManifest() throws {
        let data = try bundledCourse("ja")
        let dto = try JSONDecoder().decode(CourseDTO.self, from: data)
        let sha = RemoteContentService.sha256(data)
        XCTAssertTrue(RemoteContentService.isValid(data, for: entry("ja", dto.version, sha: sha)))
        XCTAssertFalse(RemoteContentService.isValid(data, for: entry("ja", dto.version, sha: String(repeating: "0", count: 64))),
                       "Corrupt / partial download")
        XCTAssertFalse(RemoteContentService.isValid(data, for: entry("ja", dto.version + 1, sha: sha)), "Version mismatch")
        XCTAssertFalse(RemoteContentService.isValid(data, for: entry("ko", dto.version, sha: sha)), "Wrong course")
    }

    func testApplyPendingUpdatesTheCourseAndKeepsProgress() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        ContentImporter(context: context).importBundledCourses()
        let japanese = try XCTUnwrap(try context.fetch(FetchDescriptor<Course>()).first { $0.remoteId == "ja" })
        let installedVersion = japanese.contentVersion
        let firstLesson = try XCTUnwrap(japanese.orderedLessons.first)
        firstLesson.isCompleted = true
        try context.save()

        // A newer version of the course waiting in the pending folder.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: try bundledCourse("ja")) as? [String: Any])
        json["version"] = installedVersion + 1
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try JSONSerialization.data(withJSONObject: json).write(to: directory.appendingPathComponent("course_ja.json"))
        XCTAssertEqual(RemoteContentService.pendingVersions(in: directory), ["ja": installedVersion + 1])

        let updated = RemoteContentService.applyPending(in: context, directory: directory)
        XCTAssertEqual(updated, ["ja"])
        XCTAssertEqual(japanese.contentVersion, installedVersion + 1)
        XCTAssertTrue(firstLesson.isCompleted, "Progress is kept")
        XCTAssertTrue(RemoteContentService.pendingFiles(in: directory).isEmpty, "Applied files are removed")
    }

    func testOlderPendingFileIsIgnored() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        ContentImporter(context: context).importBundledCourses()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try bundledCourse("ko").write(to: directory.appendingPathComponent("course_ko.json"))
        XCTAssertTrue(RemoteContentService.applyPending(in: context, directory: directory).isEmpty, "Same version → nothing to do")
        XCTAssertTrue(RemoteContentService.pendingFiles(in: directory).isEmpty)
    }
}
