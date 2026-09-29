//
//  GamificationManager.swift
//  LanguageApp
//
//  Hearts (lives) system. Free users lose a heart per mistake; hearts refill over time.
//  Premium users have unlimited hearts.
//

import Foundation
import Observation

@Observable final class GamificationManager {
    static let maxHearts = 5
    /// One heart every 30 minutes.
    static let refillInterval: TimeInterval = 30 * 60

    private enum Keys {
        static let hearts = "gamification.hearts"
        static let lastRefill = "gamification.lastRefill"
    }

    private let defaults: UserDefaults
    private(set) var hearts: Int {
        didSet { defaults.set(hearts, forKey: Keys.hearts) }
    }
    private var lastRefill: Date {
        didSet { defaults.set(lastRefill, forKey: Keys.lastRefill) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hearts = defaults.object(forKey: Keys.hearts) as? Int ?? Self.maxHearts
        self.lastRefill = defaults.object(forKey: Keys.lastRefill) as? Date ?? .now
        refreshHearts()
    }

    var isFull: Bool { hearts >= Self.maxHearts }

    func hasHearts(isPremium: Bool) -> Bool {
        isPremium || hearts > 0
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
        guard !isPremium else { return }
        refreshHearts(now: now)
        if hearts >= Self.maxHearts { lastRefill = now }
        hearts = max(0, hearts - 1)
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
}
