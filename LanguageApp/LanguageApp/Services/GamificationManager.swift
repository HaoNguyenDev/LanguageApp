//
//  GamificationManager.swift
//  LanguageApp
//
//  Hearts (lives) system. Free users lose a heart per mistake; hearts refill over time.
//  Premium users have unlimited hearts.
//
//  Streak freezes: free users buy them with XP (up to `maxStreakFreezes` equipped);
//  Plus users are always fully equipped. Applied to missed days by `StreakFreezeService`.
//

import Foundation
import Observation

@Observable final class GamificationManager {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}

    static let maxHearts = 5
    /// One heart every 30 minutes.
    static let refillInterval: TimeInterval = 30 * 60

    /// Streak freezes a learner can hold at once (and the longest gap a freeze can cover).
    static let maxStreakFreezes = 2
    static let streakFreezeCost = 50

    private enum Keys {
        static let hearts = "gamification.hearts"
        static let lastRefill = "gamification.lastRefill"
        static let streakFreezes = "gamification.streakFreezes"
        static let spentXP = "gamification.spentXP"
        static let streakLostAfterDayKey = "gamification.streakLostAfterDayKey"
    }

    private let defaults: UserDefaults
    private(set) var hearts: Int {
        didSet { defaults.set(hearts, forKey: Keys.hearts) }
    }
    private var lastRefill: Date {
        didSet { defaults.set(lastRefill, forKey: Keys.lastRefill) }
    }

    /// Streak freezes owned by a free user.
    private(set) var streakFreezes: Int {
        didSet { defaults.set(streakFreezes, forKey: Keys.streakFreezes) }
    }
    /// XP spent on streak freezes. Total XP (lifetime) stays unchanged; the spendable balance is total − spent.
    private(set) var spentXP: Int {
        didSet { defaults.set(spentXP, forKey: Keys.spentXP) }
    }
    /// Last kept day of a streak that was lost (gap too long for the freezes owned),
    /// so freezes bought later can't bring that streak back.
    var streakLostAfterDayKey: String? {
        didSet { defaults.set(streakLostAfterDayKey, forKey: Keys.streakLostAfterDayKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hearts = defaults.object(forKey: Keys.hearts) as? Int ?? Self.maxHearts
        self.lastRefill = defaults.object(forKey: Keys.lastRefill) as? Date ?? .now
        self.streakFreezes = defaults.object(forKey: Keys.streakFreezes) as? Int ?? 0
        self.spentXP = defaults.object(forKey: Keys.spentXP) as? Int ?? 0
        self.streakLostAfterDayKey = defaults.string(forKey: Keys.streakLostAfterDayKey)
        refreshHearts()
    }

    var isFull: Bool { hearts >= Self.maxHearts }

    func hasHearts(isPremium: Bool) -> Bool {
        isPremium || DebugSettings.shared.hasUnlimitedHearts || hearts > 0
    }

    /// Adds hearts earned by elapsed time.
    func refreshHearts(now: Date = .now) {
        guard hearts < Self.maxHearts else {
            lastRefill = now
            return
        }
        let elapsed = now.timeIntervalSince(lastRefill)
        let earned = Int(elapsed / Self.refillInterval)
        guard earned > 0 else { return }
        hearts = min(Self.maxHearts, hearts + earned)
        lastRefill = hearts >= Self.maxHearts ? now : lastRefill.addingTimeInterval(Double(earned) * Self.refillInterval)
    }

    func loseHeart(isPremium: Bool, now: Date = .now) {
        guard !isPremium, !DebugSettings.shared.hasUnlimitedHearts else { return }
        refreshHearts(now: now)
        if hearts >= Self.maxHearts { lastRefill = now }
        hearts = max(0, hearts - 1)
    }

    /// Developer menu: set hearts directly (e.g. 0 to test the out-of-hearts screen).
    func debugSetHearts(_ value: Int) {
        hearts = min(max(0, value), Self.maxHearts)
        lastRefill = .now
    }

    func refillAll() {
        hearts = Self.maxHearts
        lastRefill = .now
    }

    /// When the next heart arrives (nil if full).
    func nextHeartDate(now: Date = .now) -> Date? {
        guard hearts < Self.maxHearts else { return nil }
        return lastRefill.addingTimeInterval(Self.refillInterval)
    }

    // MARK: - Streak freeze

    enum StreakFreezePurchase: Equatable {
        case bought, alreadyFull, notEnoughXP
    }

    /// Freezes ready to use: Plus is always fully equipped.
    func availableStreakFreezes(isPremium: Bool) -> Int {
        isPremium ? Self.maxStreakFreezes : streakFreezes
    }

    /// XP that can still be spent (lifetime XP minus XP spent on freezes).
    func xpBalance(totalXP: Int) -> Int {
        max(0, totalXP - spentXP)
    }

    func canBuyStreakFreeze(totalXP: Int) -> StreakFreezePurchase {
        if streakFreezes >= Self.maxStreakFreezes { return .alreadyFull }
        if xpBalance(totalXP: totalXP) < Self.streakFreezeCost { return .notEnoughXP }
        return .bought
    }

    @discardableResult
    func buyStreakFreeze(totalXP: Int) -> StreakFreezePurchase {
        let result = canBuyStreakFreeze(totalXP: totalXP)
        guard result == .bought else { return result }
        streakFreezes += 1
        spentXP += Self.streakFreezeCost
        return .bought
    }

    /// Consumes freezes for missed days (free users only; Plus never runs out).
    func useStreakFreezes(_ count: Int, isPremium: Bool) {
        guard !isPremium else { return }
        streakFreezes = max(0, streakFreezes - count)
    }

    /// Developer menu ("Reset everything"): full hearts, no freezes, no XP spent.
    func debugResetAll() {
        refillAll()
        streakFreezes = 0
        spentXP = 0
        streakLostAfterDayKey = nil
    }

    /// Developer menu: set the number of freezes directly.
    func debugSetStreakFreezes(_ value: Int) {
        streakFreezes = min(max(0, value), Self.maxStreakFreezes)
        streakLostAfterDayKey = nil
    }
}
