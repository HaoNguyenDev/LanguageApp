//
//  LanguageAppTests.swift
//  LanguageAppTests
//
//  Created by Hao Nguyen on 29/09/2026.
//

import XCTest
import SwiftData
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
        let japanese = try XCTUnwrap(courses.first { $0.remoteId == "ja" })
        XCTAssertEqual(japanese.orderedLessons.count, 4)
        XCTAssertEqual(japanese.allItems.count, 24)

        // Learn a word, then re-import → SRS state must be kept, no duplicates.
        let word = try XCTUnwrap(japanese.allItems.first)
        word.srsState = SRSScheduler().introduce()
        importer.importBundledCourses()
        XCTAssertEqual(try context.fetch(FetchDescriptor<VocabItem>()).count, 144)
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
        XCTAssertEqual(try context.fetch(FetchDescriptor<VocabItem>()).count, 143)
        let removedLeft = try context.fetch(FetchDescriptor<VocabItem>(predicate: #Predicate { $0.remoteId == removedId }))
        XCTAssertTrue(removedLeft.isEmpty, "Words removed from the content are deleted")
    }
}
