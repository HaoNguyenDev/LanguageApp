//
//  WordReminderPlanner.swift
//  LanguageApp
//
//  Word reminders: every N minutes (picked in Settings) a quiet notification shows a few words of
//  the course being learned – the words of the latest completed lesson plus the words last graded
//  Again / Hard in a review. Only between 08:00 and 22:00. Planned ahead as one-shot notifications
//  (iOS keeps at most 64) and re-planned whenever the app opens or closes, together with the
//  smart notifications (`NotificationManager.reschedule`).
//

import Foundation
import SwiftData

struct ReminderWord: Equatable {
    let id: String
    let term: String
    let reading: String?
    let meaning: String
    /// Last graded Again / Hard in a review.
    let isHard: Bool
    /// `WordWidgetData.Difficulty` raw value: 0 normal, 1 Hard, 2 Again.
    var level: Int = 0
}

enum WordReminderPlanner {
    static let intervalOptions = [15, 20, 30, 45, 60, 90, 120]
    static let wordCountOptions = [1, 2, 3, 4, 5]
    /// Reminders are sent from 08:00 until 22:00 only.
    static let activeStartHour = 8
    static let activeEndHour = 22
    /// Words graded Again / Hard included at most (most recently reviewed first).
    static let maxHardWords = 20
    static let idPrefix = "words-"

    struct Planned: Equatable {
        let id: String
        let date: Date
        let words: [ReminderWord]
    }

    // MARK: - Pure calculations (unit tested)

    /// Next `count` times, every `intervalMinutes` after `now`, skipping 22:00–08:00.
    static func fireDates(now: Date, intervalMinutes: Int, count: Int, calendar: Calendar = .current) -> [Date] {
        guard intervalMinutes > 0, count > 0 else { return [] }
        let step = TimeInterval(intervalMinutes * 60)
        var dates: [Date] = []
        var next = now.addingTimeInterval(step)
        var guardCounter = 0
        while dates.count < count, guardCounter < count * 10 {
            guardCounter += 1
            let hour = calendar.component(.hour, from: next)
            if hour >= activeStartHour && hour < activeEndHour {
                dates.append(next)
                next = next.addingTimeInterval(step)
            } else {
                // Jump to 08:00 of the same morning (after midnight) or of the next day (late evening).
                let day = hour < activeStartHour ? next : calendar.date(byAdding: .day, value: 1, to: next) ?? next
                next = calendar.date(bySettingHour: activeStartHour, minute: 0, second: 0, of: day) ?? next.addingTimeInterval(step)
            }
        }
        return dates
    }

    /// The words shown at `date`: a window that moves through the pool with the clock, so the
    /// rotation continues where it was even after the notifications are re-planned.
    static func words(at date: Date, intervalMinutes: Int, pool: [ReminderWord], count: Int) -> [ReminderWord] {
        // Shared with the widget, so both show the same words at the same time.
        WordWidgetData.words(slot: WordWidgetData.slot(at: date, intervalMinutes: intervalMinutes), pool: pool, count: count)
    }

    static func plan(now: Date, intervalMinutes: Int, wordsPerNotification: Int, pool: [ReminderWord],
                     maxCount: Int, calendar: Calendar = .current) -> [Planned] {
        guard !pool.isEmpty, maxCount > 0 else { return [] }
        return fireDates(now: now, intervalMinutes: intervalMinutes, count: maxCount, calendar: calendar).map { date in
            Planned(id: "\(idPrefix)\(Int(date.timeIntervalSince1970))",
                    date: date,
                    words: words(at: date, intervalMinutes: intervalMinutes, pool: pool, count: wordsPerNotification))
        }
    }

    /// "🔁 こんにちは (konnichiwa) – xin chào", one word per line; 🔁 marks a word graded Again / Hard.
    static func body(for words: [ReminderWord]) -> String {
        words.map { word in
            var line = word.isHard ? "🔁 " : ""
            line += word.term
            if let reading = word.reading, !reading.isEmpty, reading != word.term { line += " (\(reading))" }
            return line + " – " + word.meaning
        }
        .joined(separator: "\n")
    }

    // MARK: - Word pool

    /// Words of the latest completed lesson of the course, then the words last graded Again / Hard.
    static func pool(courseId: String, in context: ModelContext) -> [ReminderWord] {
        let id = courseId
        let completed = FetchDescriptor<Lesson>(predicate: #Predicate { $0.isCompleted })
        let latestLesson = ((try? context.fetch(completed)) ?? [])
            .filter { $0.course?.remoteId == id && $0.completedAt != nil }
            .max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        let again = ReviewGrade.again.rawValue, hard = ReviewGrade.hard.rawValue
        let hardDescriptor = FetchDescriptor<VocabItem>(predicate: #Predicate {
            $0.courseId == id && ($0.lastReviewGrade == again || $0.lastReviewGrade == hard)
        })
        let hardItems = ((try? context.fetch(hardDescriptor)) ?? [])
            .sorted { ($0.lastReviewedAt ?? .distantPast) > ($1.lastReviewedAt ?? .distantPast) }
            .prefix(maxHardWords)
        return pool(latestLessonWords: latestLesson?.sortedItems ?? [], hardWords: Array(hardItems))
    }

    static func pool(latestLessonWords: [VocabItem], hardWords: [VocabItem]) -> [ReminderWord] {
        let hardIds = Set(hardWords.map(\.remoteId))
        var seen = Set<String>()
        var result: [ReminderWord] = []
        for item in latestLessonWords + hardWords where seen.insert(item.remoteId).inserted {
            let isHard = hardIds.contains(item.remoteId)
            let level: WordWidgetData.Difficulty = !isHard ? .normal
                : item.lastReviewGrade == ReviewGrade.again.rawValue ? .again : .hard
            result.append(ReminderWord(id: item.remoteId, term: item.term, reading: item.reading,
                                       meaning: item.meaning.text, isHard: isHard, level: level.rawValue))
        }
        return result
    }
}
