//
//  MessageCatalog.swift
//  LanguageApp
//
//  Texts the app shows that can change without an app update: the welcome-back toast and the
//  texts of notifications / content-update toasts. They come from the "LinguaPath – App Messages"
//  sheet (build_messages.py → messages.json), published with the course content and downloaded by
//  `RemoteContentService`. Order of precedence: downloaded file → bundled Resources/Content/messages.json
//  → the strings built into the app (Localizable lang_xx.json).
//

import Foundation
import SwiftData

/// messages.json
struct AppMessages: Codable, Equatable {
    struct Welcome: Codable, Equatable {
        let id: String
        /// any · streak · no_streak · away · morning · evening · studied_today
        let when: String
        let minDaysAway: Int
        let weight: Int
        let title: LocalizedText
        let message: LocalizedText
    }

    struct Text: Codable, Equatable {
        let id: String
        /// reminder · review_due · streak_risk · word_reminder · content_updated · content_new_units · content_new_words
        let key: String
        let title: LocalizedText
        let body: LocalizedText?
    }

    var version: Int = 0
    var welcome: [Welcome] = []
    var texts: [Text] = []

    static let empty = AppMessages()
}

/// What the welcome message can depend on.
struct WelcomeContext: Equatable {
    var streak = 0
    /// Days since the last day with XP (nil = never studied).
    var daysSinceStudy: Int?
    var studiedToday = false
    var hour = 12
}

enum MessageCatalog {
    private static let cacheFile = "messages.json"
    private static let lastWelcomeKey = "messages.lastWelcomeId"

    // MARK: - Loading

    private static var cached: AppMessages?

    /// Downloaded messages when newer than the bundled ones, else the bundled ones, else empty.
    static var current: AppMessages {
        if let cached { return cached }
        let downloaded = load(from: cacheURL)
        let bundled = Bundle.main.url(forResource: "messages", withExtension: "json").flatMap(load(from:))
        let best = [downloaded, bundled].compactMap { $0 }.max { $0.version < $1.version } ?? .empty
        cached = best
        return best
    }

    static var installedVersion: Int { current.version }

    static var cacheURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("RemoteContent", isDirectory: true)
            .appendingPathComponent(cacheFile)
    }

    private static func load(from url: URL) -> AppMessages? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppMessages.self, from: data)
    }

    /// Saves downloaded messages (already checked) and uses them from now on.
    static func install(_ data: Data) throws {
        let messages = try JSONDecoder().decode(AppMessages.self, from: data)
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
        cached = messages
    }

    // MARK: - Texts (notifications, toasts)

    /// A random active variant of `key` with placeholders filled, or nil (→ use the built-in text).
    static func text(_ key: String, values: [String: String] = [:],
                     in messages: AppMessages = current) -> (title: String, body: String?)? {
        guard let variant = messages.texts.filter({ $0.key == key }).randomElement() else { return nil }
        return (fill(variant.title.text, values), variant.body.map { fill($0.text, values) })
    }

    // MARK: - Welcome back

    /// Streak, days away and time of day from the learner's activity.
    static func welcomeContext(activities: [DailyActivity], now: Date = .now,
                               calendar: Calendar = .current) -> WelcomeContext {
        let lastStudy = activities.filter { $0.xp > 0 }.map(\.date).max()
        let daysAway = lastStudy.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: now)).day ?? 0
        }
        return WelcomeContext(streak: ProgressService.streak(from: activities, today: now, calendar: calendar),
                              daysSinceStudy: daysAway,
                              studiedToday: daysAway == 0,
                              hour: calendar.component(.hour, from: now))
    }

    static func matches(_ message: AppMessages.Welcome, _ context: WelcomeContext) -> Bool {
        switch message.when {
        case "any": return true
        case "streak": return context.streak >= 2
        case "no_streak": return context.streak == 0
        case "away": return (context.daysSinceStudy ?? 0) >= max(message.minDaysAway, 1)
        case "morning": return (5..<12).contains(context.hour)
        case "evening": return (18..<24).contains(context.hour)
        case "studied_today": return context.studiedToday
        default: return false
        }
    }

    /// Weighted random pick among the matching messages, avoiding the one shown last time.
    static func pickWelcome(_ messages: [AppMessages.Welcome], context: WelcomeContext, lastId: String?,
                            using rng: inout some RandomNumberGenerator) -> AppMessages.Welcome? {
        var candidates = messages.filter { matches($0, context) }
        if candidates.count > 1 { candidates.removeAll { $0.id == lastId } }
        let total = candidates.reduce(0) { $0 + max($1.weight, 1) }
        guard total > 0 else { return nil }
        var roll = Int.random(in: 0..<total, using: &rng)
        for message in candidates {
            roll -= max(message.weight, 1)
            if roll < 0 { return message }
        }
        return candidates.last
    }

    /// Title and message of the welcome-back toast (built-in text when nothing matches).
    static func welcome(context: WelcomeContext, values: [String: String],
                        in messages: AppMessages = current, defaults: UserDefaults = .standard) -> (title: String, message: String) {
        var rng = SystemRandomNumberGenerator()
        guard let picked = pickWelcome(messages.welcome, context: context,
                                       lastId: defaults.string(forKey: lastWelcomeKey), using: &rng) else {
            return ("welcome_back_title".localized(), "welcome_back_message".localized())
        }
        defaults.set(picked.id, forKey: lastWelcomeKey)
        return (fill(picked.title.text, values), fill(picked.message.text, values))
    }

    /// The welcome-back toast for the learner right now.
    static func welcomeToast(in context: ModelContext, settings: UserSettings, now: Date = .now) -> UserMessageItem {
        let welcomeContext = Self.welcomeContext(activities: ProgressService.allActivities(in: context), now: now)
        let course = NotificationManager.currentCourse(in: context, settings: settings)
        let welcome = Self.welcome(context: welcomeContext, values: [
            "name": settings.username ?? "",
            "streak": "\(welcomeContext.streak)",
            "days_away": "\(welcomeContext.daysSinceStudy ?? 0)",
            "course": course?.name.text ?? ""
        ])
        return UserMessageItem(title: welcome.title, message: welcome.message).readable()
    }

    /// Developer menu readout.
    static var summary: String {
        let messages = current
        return messages.version == 0
            ? "Messages: built-in texts (nothing published or bundled)"
            : "Messages v\(messages.version) · \(messages.welcome.count) welcome · \(messages.texts.count) texts"
    }

    // MARK: - Placeholders

    /// Replaces {name}, {streak}… An empty {name} is removed with the punctuation around it
    /// ("Hi, {name}!" → "Hi!", "こんにちは、{name}さん！" → "こんにちは！").
    static func fill(_ text: String, _ values: [String: String]) -> String {
        var result = text
        if (values["name"] ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            for pattern in [", {name}", "，{name}", "、{name}さん", "、{name}", " {name}님", "{name}님", "{name}さん", " {name}", "{name}"] {
                result = result.replacingOccurrences(of: pattern, with: "")
            }
            // "{name}, ..." at the start leaves ", ..." behind.
            while let first = result.first, ",，、 ".contains(first) { result.removeFirst() }
        }
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
