//
//  DebugSettings.swift
//  LanguageApp
//
//  Developer switches for testing without changing code. Edited in Settings ▸ Developer.
//  Available only when the `DEVELOPER_MENU` compilation condition is set (Debug today; a future
//  "Beta" configuration for TestFlight can turn it on without `DEBUG`). In Release builds – and
//  while unit tests run – every switch reads as off, so nothing here can leak into an App Store build.
//

import Foundation
import Observation

@Observable final class DebugSettings {
    // Keep deinit nonisolated (see LessonSessionViewModel).
    nonisolated deinit {}

    static let shared = DebugSettings()

    /// True when built with `DEVELOPER_MENU` (Debug), false in Release and during unit tests.
    static let isAvailable: Bool = {
        #if DEVELOPER_MENU
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        #else
        return false
        #endif
    }()

    enum PremiumOverride: String, CaseIterable, Identifiable {
        case none, free, plus
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: return "StoreKit (real)"
            case .free: return "Force Free"
            case .plus: return "Force Plus"
            }
        }
    }

    /// Question type for the second pass of a lesson.
    enum QuestionKind: String, CaseIterable, Identifiable {
        case mixed, chooseTerm, listen, typeTerm, typeListening
        var id: String { rawValue }
        var title: String {
            switch self {
            case .mixed: return "Mixed (normal)"
            case .chooseTerm: return "Choose the word"
            case .listen: return "Listen & choose"
            case .typeTerm: return "Type the word"
            case .typeListening: return "Type what you hear"
            }
        }
    }

    private enum Keys {
        static let prefix = "debug."
        static let unlockAllLessons = prefix + "unlockAllLessons"
        static let unlimitedHearts = prefix + "unlimitedHearts"
        static let premiumOverride = prefix + "premiumOverride"
        static let questionKind = prefix + "questionKind"
        static let skipIntroCards = prefix + "skipIntroCards"
        static let shortLessons = prefix + "shortLessons"
        static let skipMatchPairs = prefix + "skipMatchPairs"
        static let showAnswers = prefix + "showAnswers"
    }

    private let defaults: UserDefaults

    // MARK: Stored switches (edited by the developer menu)

    var unlockAllLessons: Bool { didSet { defaults.set(unlockAllLessons, forKey: Keys.unlockAllLessons) } }
    var unlimitedHearts: Bool { didSet { defaults.set(unlimitedHearts, forKey: Keys.unlimitedHearts) } }
    var premiumOverride: PremiumOverride { didSet { defaults.set(premiumOverride.rawValue, forKey: Keys.premiumOverride) } }
    var questionKind: QuestionKind { didSet { defaults.set(questionKind.rawValue, forKey: Keys.questionKind) } }
    var skipIntroCards: Bool { didSet { defaults.set(skipIntroCards, forKey: Keys.skipIntroCards) } }
    /// Only the first 3 words of a lesson → finish a lesson in seconds.
    var shortLessons: Bool { didSet { defaults.set(shortLessons, forKey: Keys.shortLessons) } }
    var skipMatchPairs: Bool { didSet { defaults.set(skipMatchPairs, forKey: Keys.skipMatchPairs) } }
    /// Shows the question type and the correct answer above each exercise.
    var showAnswers: Bool { didSet { defaults.set(showAnswers, forKey: Keys.showAnswers) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        unlockAllLessons = defaults.bool(forKey: Keys.unlockAllLessons)
        unlimitedHearts = defaults.bool(forKey: Keys.unlimitedHearts)
        premiumOverride = PremiumOverride(rawValue: defaults.string(forKey: Keys.premiumOverride) ?? "") ?? .none
        questionKind = QuestionKind(rawValue: defaults.string(forKey: Keys.questionKind) ?? "") ?? .mixed
        skipIntroCards = defaults.bool(forKey: Keys.skipIntroCards)
        shortLessons = defaults.bool(forKey: Keys.shortLessons)
        skipMatchPairs = defaults.bool(forKey: Keys.skipMatchPairs)
        showAnswers = defaults.bool(forKey: Keys.showAnswers)
    }

    func resetAll() {
        unlockAllLessons = false
        unlimitedHearts = false
        premiumOverride = .none
        questionKind = .mixed
        skipIntroCards = false
        shortLessons = false
        skipMatchPairs = false
        showAnswers = false
    }

    // MARK: Effective values – always "off" outside Debug builds. App code reads only these.

    private var on: Bool { Self.isAvailable }

    var unlocksAllLessons: Bool { on && unlockAllLessons }
    var hasUnlimitedHearts: Bool { on && unlimitedHearts }
    /// nil = use the real StoreKit entitlement.
    var forcedPremium: Bool? {
        guard on else { return nil }
        switch premiumOverride {
        case .none: return nil
        case .free: return false
        case .plus: return true
        }
    }
    var forcedQuestionKind: QuestionKind? { on && questionKind != .mixed ? questionKind : nil }
    var skipsIntroCards: Bool { on && skipIntroCards }
    var lessonWordLimit: Int? { on && shortLessons ? 3 : nil }
    var skipsMatchPairs: Bool { on && skipMatchPairs }
    var showsAnswers: Bool { on && showAnswers }

    /// Number of switches that change behavior (shown as a badge in Settings).
    var activeCount: Int {
        guard on else { return 0 }
        return [unlockAllLessons, unlimitedHearts, premiumOverride != .none, questionKind != .mixed,
                skipIntroCards, shortLessons, skipMatchPairs, showAnswers].filter { $0 }.count
    }
}
