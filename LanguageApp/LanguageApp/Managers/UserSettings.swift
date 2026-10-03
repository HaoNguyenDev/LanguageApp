//
//  UserSettings.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import Foundation
import SwiftUI
import Observation

extension UserSettings {
    // MARK: - Keys
    private enum Keys {
        static let username = "username"
        static let languageCode = "languageCode"
        static let colorSchemeOption = "colorSchemeOption"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let selectedCourseId = "selectedCourseId"
        static let dailyGoalXP = "dailyGoalXP"
        static let soundEnabled = "soundEnabled"
        static let autoPlayAudio = "autoPlayAudio"
        static let reminderEnabled = "reminderEnabled"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let smartReminderTime = "smartReminderTime"
        static let hasSeenReviewGuide = "hasSeenReviewGuide"
        static let wordRemindersEnabled = "wordRemindersEnabled"
        static let wordReminderMinutes = "wordReminderMinutes"
        static let wordsPerReminder = "wordsPerReminder"
    }
}

/// Local user preferences (UserDefaults). Learning progress lives in SwiftData.
@Observable final class UserSettings {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}


    private let defaults: UserDefaults

    private(set) var colorSchemeOption: ColorSchemeOption = .system {
        didSet {
            defaults.set(colorSchemeOption.rawValue, forKey: Keys.colorSchemeOption)
            updateTheme(colorSchemeOption)
        }
    }

    /// UI language (eng / chs / vi) – see `LanguageCode`.
    var languageCode: String? {
        didSet {
            Logger.shared.info("languageCode set to: \(languageCode ?? "nil")")
            defaults.set(languageCode, forKey: Keys.languageCode)
        }
    }

    private(set) var themeSet: Theme

    /// Display name shown in the header / profile.
    var username: String? {
        didSet { defaults.set(username, forKey: Keys.username) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    /// `Course.remoteId` of the language being learned (e.g. "ja").
    var selectedCourseId: String? {
        didSet { defaults.set(selectedCourseId, forKey: Keys.selectedCourseId) }
    }

    var dailyGoalXP: Int {
        didSet { defaults.set(dailyGoalXP, forKey: Keys.dailyGoalXP) }
    }

    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    /// Speak new words automatically (TTS).
    var autoPlayAudio: Bool {
        didSet { defaults.set(autoPlayAudio, forKey: Keys.autoPlayAudio) }
    }

    var reminderEnabled: Bool {
        didSet { defaults.set(reminderEnabled, forKey: Keys.reminderEnabled) }
    }

    var reminderHour: Int {
        didSet { defaults.set(reminderHour, forKey: Keys.reminderHour) }
    }

    var reminderMinute: Int {
        didSet { defaults.set(reminderMinute, forKey: Keys.reminderMinute) }
    }

    /// Word reminders: notifications with words of the latest lesson + words graded Again / Hard.
    var wordRemindersEnabled: Bool {
        didSet { defaults.set(wordRemindersEnabled, forKey: Keys.wordRemindersEnabled) }
    }
    /// Minutes between two word reminders (`WordReminderPlanner.intervalOptions`).
    var wordReminderMinutes: Int {
        didSet { defaults.set(wordReminderMinutes, forKey: Keys.wordReminderMinutes) }
    }
    /// Words shown in one reminder (`WordReminderPlanner.wordCountOptions`).
    var wordsPerReminder: Int {
        didSet { defaults.set(wordsPerReminder, forKey: Keys.wordsPerReminder) }
    }

    /// The "How reviews work" guide is shown automatically before the first review session.
    var hasSeenReviewGuide: Bool {
        didSet { defaults.set(hasSeenReviewGuide, forKey: Keys.hasSeenReviewGuide) }
    }

    /// Remind at the time the learner usually studies (falls back to `reminderHour:reminderMinute`).
    var smartReminderTime: Bool {
        didSet { defaults.set(smartReminderTime, forKey: Keys.smartReminderTime) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let rawValue = defaults.string(forKey: Keys.colorSchemeOption),
           let savedOption = ColorSchemeOption(rawValue: rawValue) {
            self.colorSchemeOption = savedOption
        } else {
            self.colorSchemeOption = .system
        }

        self.username = defaults.string(forKey: Keys.username)
        self.languageCode = defaults.string(forKey: Keys.languageCode) ?? LanguageCode.deviceDefault.rawValue
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.selectedCourseId = defaults.string(forKey: Keys.selectedCourseId)
        self.dailyGoalXP = defaults.object(forKey: Keys.dailyGoalXP) as? Int ?? DailyGoal.regular.xp
        self.soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        self.autoPlayAudio = defaults.object(forKey: Keys.autoPlayAudio) as? Bool ?? true
        self.reminderEnabled = defaults.bool(forKey: Keys.reminderEnabled)
        self.reminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 20
        self.reminderMinute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
        self.smartReminderTime = defaults.object(forKey: Keys.smartReminderTime) as? Bool ?? true
        self.hasSeenReviewGuide = defaults.bool(forKey: Keys.hasSeenReviewGuide)
        self.wordRemindersEnabled = defaults.bool(forKey: Keys.wordRemindersEnabled)
        self.wordReminderMinutes = defaults.object(forKey: Keys.wordReminderMinutes) as? Int ?? 30
        self.wordsPerReminder = defaults.object(forKey: Keys.wordsPerReminder) as? Int ?? 3

        themeSet = LightTheme()
        updateTheme(colorSchemeOption)

        if let language = LanguageCode(rawValue: languageCode ?? LanguageCode.eng.rawValue)?.getLanguage() {
            LanguageManager.shared.setLanguage(language: language)
        }
    }

    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = comps.hour ?? 20
            reminderMinute = comps.minute ?? 0
        }
    }

    /// Clears onboarding + preferences (not SwiftData progress).
    func resetOnboarding() {
        hasCompletedOnboarding = false
        selectedCourseId = nil
    }
}

extension UserSettings {
    var theme: Theme {
        return themeSet
    }

    func setColorScheme(_ option: ColorSchemeOption, systemColorScheme: ColorScheme = .light) {
        self.colorSchemeOption = option
        self.updateTheme(option, systemColorScheme: systemColorScheme)
    }

    private func updateTheme(_ option: ColorSchemeOption, systemColorScheme: ColorScheme = .light) {
        switch option {
        case .system:
            themeSet = systemColorScheme == .dark ? DarkTheme() : LightTheme()
        case .light:
            themeSet = LightTheme()
        case .dark:
            themeSet = DarkTheme()
        }
    }
}

// MARK: - Daily goal presets
enum DailyGoal: Int, CaseIterable, Identifiable {
    case casual = 10
    case regular = 20
    case serious = 30
    case intense = 50

    var id: Int { rawValue }
    var xp: Int { rawValue }

    var titleKey: String {
        switch self {
        case .casual: return "goal_casual"
        case .regular: return "goal_regular"
        case .serious: return "goal_serious"
        case .intense: return "goal_intense"
        }
    }

    var minutesKey: String {
        switch self {
        case .casual: return "goal_5_min"
        case .regular: return "goal_10_min"
        case .serious: return "goal_15_min"
        case .intense: return "goal_20_min"
        }
    }
}
