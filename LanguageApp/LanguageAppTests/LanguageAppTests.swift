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

    func testShortLabels() {
        XCTAssertEqual(SRSScheduler.shortLabel(for: 600), "10m")
        XCTAssertEqual(SRSScheduler.shortLabel(for: day), "1d")
        XCTAssertEqual(SRSScheduler.shortLabel(for: 60 * day), "2mo")
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
