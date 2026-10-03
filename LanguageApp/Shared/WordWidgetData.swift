//
//  WordWidgetData.swift
//  Shared by the app and the LanguageAppWidget extension (both targets compile this folder).
//
//  The app writes the words to show (same pool as the word reminders) into the App Group;
//  the widget only reads them and rotates through them with the clock. `nonisolated` because the
//  app isolates types to the main actor by default and the widget does not.
//

import Foundation

nonisolated struct WordWidgetData: Codable, Equatable, Sendable {
    nonisolated struct Word: Codable, Equatable, Sendable, Identifiable {
        let id: String
        let term: String
        let reading: String?
        let meaning: String
        /// Last graded Again / Hard → shown with a "review again" badge.
        let isHard: Bool
        /// `Difficulty` raw value (optional: data saved by an older build has none).
        var level: Int? = nil

        var difficulty: Difficulty {
            Difficulty(rawValue: level ?? (isHard ? Difficulty.hard.rawValue : Difficulty.normal.rawValue)) ?? .normal
        }
    }

    /// How hard the word was in the last review – harder words stand out more in the widget.
    nonisolated enum Difficulty: Int, Codable, Sendable, Comparable {
        case normal = 0  // new word of the latest lesson, or reviewed fine
        case hard = 1    // last graded Hard
        case again = 2   // last graded Again (forgotten)

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// UI texts in the app's language (the widget can't read the app's string files).
    nonisolated struct Texts: Codable, Equatable, Sendable {
        var title: String
        var empty: String
        var hard: String
        var next: String

        static let english = Texts(title: "Words to remember",
                                   empty: "Finish a lesson and your new words show up here.",
                                   hard: "Review again",
                                   next: "Next words")
    }

    var courseName: String
    /// Minutes between two sets of words (the word-reminder interval).
    var intervalMinutes: Int
    var words: [Word]
    var texts: Texts
    var updatedAt: Date

    static let empty = WordWidgetData(courseName: "", intervalMinutes: 30, words: [], texts: .english, updatedAt: .distantPast)

    // MARK: - App Group storage

    static let appGroup = "group.com.haonguyen.apps.LanguageApp"
    static let widgetKind = "WordWidget"
    /// Words shown at the same time by the medium widget.
    static let wordsPerEntry = 2

    private static let dataKey = "wordWidget.data"
    private static let offsetKey = "wordWidget.offset"

    static var store: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static func load(from defaults: UserDefaults = store) -> WordWidgetData? {
        guard let data = defaults.data(forKey: dataKey) else { return nil }
        return try? JSONDecoder().decode(WordWidgetData.self, from: data)
    }

    /// - Returns: true when something changed (the widget then needs a reload).
    @discardableResult
    func save(to defaults: UserDefaults = Self.store) -> Bool {
        guard Self.load(from: defaults) != self, let data = try? JSONEncoder().encode(self) else { return false }
        defaults.set(data, forKey: Self.dataKey)
        return true
    }

    /// Extra steps from the "next" button of the widget (added to the clock slot).
    static func offset(in defaults: UserDefaults = store) -> Int { defaults.integer(forKey: offsetKey) }

    static func advanceOffset(in defaults: UserDefaults = store) {
        defaults.set(offset(in: defaults) + 1, forKey: offsetKey)
    }

    // MARK: - Rotation (same as the word-reminder notifications)

    static func slot(at date: Date, intervalMinutes: Int) -> Int {
        Int(date.timeIntervalSince1970 / TimeInterval(max(intervalMinutes, 1) * 60))
    }

    static func startOfSlot(_ slot: Int, intervalMinutes: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(slot * max(intervalMinutes, 1) * 60))
    }

    /// `count` words of `pool`, a window that moves one step per slot.
    static func words<T>(slot: Int, pool: [T], count: Int) -> [T] {
        guard !pool.isEmpty, count > 0 else { return [] }
        if count >= pool.count { return pool }
        let start = ((slot * count) % pool.count + pool.count) % pool.count
        return (0..<count).map { pool[(start + $0) % pool.count] }
    }
}
