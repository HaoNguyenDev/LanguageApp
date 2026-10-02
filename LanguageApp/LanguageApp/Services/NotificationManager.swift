//
//  NotificationManager.swift
//  LanguageApp
//
//  Local notifications (the #1 retention lever for streak apps). What to send and when is
//  decided by `NotificationPlanner`; this schedules it. Call `reschedule` whenever the learner's
//  data or reminder settings change – the app does it when it becomes active / goes to the background.
//

import Foundation
import SwiftData
import UserNotifications

enum NotificationManager {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Logger.shared.error("Notification auth failed: \(error)")
            return false
        }
    }

    /// Replaces every pending notification with a fresh plan for the next days
    /// (nothing is scheduled when reminders are off).
    static func reschedule(in context: ModelContext, settings: UserSettings, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        // Only this manager schedules local notifications, so clearing everything also removes
        // the repeating reminder of older versions ("daily_study_reminder").
        center.removeAllPendingNotificationRequests()
        guard settings.reminderEnabled else { return }

        let activities = ProgressService.allActivities(in: context)
        let time = reminderTime(settings: settings, activities: activities, now: now)
        let learned = FetchDescriptor<VocabItem>(predicate: #Predicate { $0.srsDue != nil })
        let dueDates = ((try? context.fetch(learned)) ?? []).compactMap(\.srsDue)

        let input = NotificationPlanner.Input(now: now,
                                              reminderHour: time.hour,
                                              reminderMinute: time.minute,
                                              streak: ProgressService.streak(from: activities, today: now),
                                              studiedToday: ProgressService.xp(on: now, from: activities) > 0,
                                              dueDates: dueDates)
        for planned in NotificationPlanner.plan(input) {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: planned.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: planned.id, content: content(for: planned.kind), trigger: trigger))
        }
    }

    /// The learner's usual study time when "smart time" is on and there's enough history,
    /// otherwise the time picked in Settings.
    static func reminderTime(settings: UserSettings, activities: [DailyActivity],
                             now: Date = .now) -> (hour: Int, minute: Int) {
        if settings.smartReminderTime,
           let usual = NotificationPlanner.usualStudyTime(firstActiveTimes: activities.compactMap(\.firstActiveAt), now: now) {
            return usual
        }
        return (settings.reminderHour, settings.reminderMinute)
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Developer menu: one notification of each kind, 5 / 10 / 15 seconds from now
    /// (lock the device or go to the home screen to see them).
    static func debugSendSamples() {
        let center = UNUserNotificationCenter.current()
        let kinds: [NotificationPlanner.Kind] = [.reminder, .dueCards(12), .streakAtRisk(7)]
        for (index, kind) in kinds.enumerated() {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(5 * (index + 1)), repeats: false)
            center.add(UNNotificationRequest(identifier: "debug-sample-\(index)", content: content(for: kind), trigger: trigger))
        }
    }

    /// Developer menu: the scheduled notifications, earliest first ("dd/MM HH:mm · id").
    static func debugPendingSummary() async -> [String] {
        // Lines are built in the completion handler so only Sendable strings cross back.
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM HH:mm"
                let lines = requests
                    .compactMap { request -> (Date, String)? in
                        guard let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() else {
                            return nil
                        }
                        return (date, "\(formatter.string(from: date)) · \(request.identifier) · \(request.content.body)")
                    }
                    .sorted { $0.0 < $1.0 }
                    .map(\.1)
                continuation.resume(returning: lines)
            }
        }
    }

    private static func content(for kind: NotificationPlanner.Kind) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch kind {
        case .reminder:
            content.title = "reminder_title".localized()
            content.body = "reminder_body".localized()
        case .dueCards(let count):
            content.title = "reminder_review_title".localized()
            content.body = "reminder_review_body".localizedFormat(count)
        case .streakAtRisk(let days):
            content.title = "streak_risk_title".localized()
            content.body = "streak_risk_body".localizedFormat(days)
        }
        content.sound = .default
        return content
    }
}
