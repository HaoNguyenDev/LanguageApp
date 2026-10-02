//
//  NotificationPlanner.swift
//  LanguageApp
//
//  Smart notifications, planned for the next days as one-shot local notifications and
//  re-planned whenever the app becomes active or goes to the background (so a day the
//  learner already studied gets no reminder):
//  - Daily reminder at the learner's usual study time (or the time picked in Settings);
//    when enough review cards are due it says how many.
//  - Streak at risk: in the evening, when the streak would end at midnight.
//

import Foundation

enum NotificationPlanner {
    /// Days planned ahead (re-planned every time the app opens or closes).
    static let daysAhead = 7
    /// "Streak at risk" time (local), well before midnight.
    static let streakRiskHour = 21
    /// A daily reminder this close before the streak-risk one is dropped (one notification is enough).
    static let minimumGap: TimeInterval = 60 * 60
    /// Due cards needed for the "cards to review" reminder text.
    static let dueCardsThreshold = 5
    /// Days with a first activity needed before the usual time is trusted.
    static let usualTimeMinimumDays = 3
    static let usualTimeLookBackDays = 14
    /// Smart reminders stay within this window.
    static let earliestHour = 7
    static let latestHour = 21

    enum Kind: Equatable {
        case reminder
        case dueCards(Int)
        case streakAtRisk(Int)

        var idSuffix: String {
            switch self {
            case .reminder, .dueCards: return "reminder"
            case .streakAtRisk: return "streak"
            }
        }
    }

    struct Planned: Equatable {
        let id: String
        let date: Date
        let kind: Kind
    }

    struct Input {
        var now: Date
        var calendar: Calendar = .current
        var reminderHour: Int
        var reminderMinute: Int
        /// Current streak: days up to today if the learner studied today, otherwise up to yesterday.
        var streak: Int
        var studiedToday: Bool
        /// `srsDue` of every learned word.
        var dueDates: [Date]
    }

    static let idPrefix = "smart-"

    // MARK: - Plan

    static func plan(_ input: Input) -> [Planned] {
        let calendar = input.calendar
        let today = calendar.startOfDay(for: input.now)
        var planned: [Planned] = []

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if offset == 0 && input.studiedToday { continue }
            let key = ProgressService.dayKey(for: day, calendar: calendar)

            // The streak still alive at the end of that day if the learner doesn't study:
            // today → the current streak; tomorrow → only if today was studied; later → unknown.
            let streakAtRisk: Int
            switch offset {
            case 0: streakAtRisk = input.streak
            case 1: streakAtRisk = input.studiedToday ? input.streak : 0
            default: streakAtRisk = 0
            }

            var riskDate: Date?
            if streakAtRisk > 0,
               let date = calendar.date(bySettingHour: streakRiskHour, minute: 0, second: 0, of: day),
               date > input.now {
                riskDate = date
                planned.append(Planned(id: "\(idPrefix)\(key)-streak", date: date, kind: .streakAtRisk(streakAtRisk)))
            }

            guard let reminderDate = calendar.date(bySettingHour: input.reminderHour, minute: input.reminderMinute,
                                                   second: 0, of: day),
                  reminderDate > input.now else { continue }
            if let riskDate, reminderDate > riskDate.addingTimeInterval(-minimumGap) { continue }
            let due = input.dueDates.filter { $0 <= reminderDate }.count
            let kind: Kind = due >= dueCardsThreshold ? .dueCards(due) : .reminder
            planned.append(Planned(id: "\(idPrefix)\(key)-reminder", date: reminderDate, kind: kind))
        }
        return planned.sorted { $0.date < $1.date }
    }

    // MARK: - Usual study time

    /// Median time of day of the first activity over the last two weeks, rounded down to 15 minutes
    /// and kept between 07:00 and 21:00; nil until there are a few days of history.
    static func usualStudyTime(firstActiveTimes: [Date], now: Date = .now,
                               calendar: Calendar = .current) -> (hour: Int, minute: Int)? {
        guard let since = calendar.date(byAdding: .day, value: -usualTimeLookBackDays, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        let minutes = firstActiveTimes
            .filter { $0 >= since && $0 <= now }
            .map { date -> Int in
                let c = calendar.dateComponents([.hour, .minute], from: date)
                return (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
            .sorted()
        guard minutes.count >= usualTimeMinimumDays else { return nil }
        let median = minutes[minutes.count / 2]
        let rounded = min(max(median / 15 * 15, earliestHour * 60), latestHour * 60)
        return (rounded / 60, rounded % 60)
    }
}
