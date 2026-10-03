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
import UIKit
import UserNotifications

enum NotificationManager {
    // MARK: - Permission

    enum Permission: Equatable {
        /// The learner hasn't been asked yet – the system dialog can still be shown.
        case notAsked
        case allowed
        /// Turned off: iOS won't ask again, only Settings ▸ Notifications can turn it back on.
        case denied
    }

    static func permission() async -> Permission {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .notDetermined: continuation.resume(returning: .notAsked)
                case .denied: continuation.resume(returning: .denied)
                default: continuation.resume(returning: .allowed)   // authorized, provisional, ephemeral
                }
            }
        }
    }

    /// Asks with the system dialog the first time; afterwards only reports the current state.
    /// - Returns: true when notifications can be delivered. On false, show `notificationPermissionAlert`
    ///   (the system dialog can't be shown again – the learner has to allow it in Settings).
    static func ensurePermission() async -> Bool {
        switch await permission() {
        case .allowed: return true
        case .denied: return false
        case .notAsked: return await requestAuthorization()
        }
    }

    /// This app's page in Settings ▸ Notifications.
    static var settingsURL: URL? {
        URL(string: UIApplication.openNotificationSettingsURLString)
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Logger.shared.error("Notification auth failed: \(error)")
            return false
        }
    }

    /// iOS keeps at most 64 pending notifications per app; a request added beyond that can be dropped.
    /// The plan leaves a few slots free so a developer test (or anything added later) always fits.
    static let maxPending = 56

    /// Repeating daily reminder of older app versions (replaced by the planned smart reminders).
    private static let legacyReminderId = "daily_study_reminder"

    /// Notifications this manager plans (and replaces on every `reschedule`). Anything else –
    /// e.g. a developer-menu test sent "in 5 s" – is left alone.
    static func isPlanned(_ identifier: String) -> Bool {
        identifier.hasPrefix(NotificationPlanner.idPrefix)
            || identifier.hasPrefix(WordReminderPlanner.idPrefix)
            || identifier == legacyReminderId
    }

    /// Re-plans run one after another, so two quick calls (active → background) can't interleave.
    private static var rescheduleTask: Task<Void, Never>?

    /// Replaces the planned notifications with a fresh plan: the smart reminders for the next days
    /// (daily reminder on) and the word reminders (word reminders on) in the slots that are left.
    static func reschedule(in context: ModelContext, settings: UserSettings, now: Date = .now) {
        let smart = settings.reminderEnabled ? smartReminderRequests(in: context, settings: settings, now: now) : []
        let words = settings.wordRemindersEnabled
            ? wordReminderRequests(in: context, settings: settings, maxCount: maxPending - smart.count, now: now)
            : []
        let requests = smart + words
        let previous = rescheduleTask
        rescheduleTask = Task {
            await previous?.value
            let center = UNUserNotificationCenter.current()
            let old = await pendingIdentifiers().filter(isPlanned)
            center.removePendingNotificationRequests(withIdentifiers: old)
            requests.forEach { center.add($0) }
        }
    }

    /// Identifiers of the pending notifications (only Sendable strings leave the completion handler).
    private static func pendingIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier))
            }
        }
    }

    private static func smartReminderRequests(in context: ModelContext, settings: UserSettings, now: Date) -> [UNNotificationRequest] {

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
        return NotificationPlanner.plan(input).map { planned in
            UNNotificationRequest(identifier: planned.id, content: content(for: planned.kind), trigger: trigger(at: planned.date))
        }
    }

    private static func trigger(at date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    /// Course the learner is studying (Settings), or the first one.
    static func currentCourse(in context: ModelContext, settings: UserSettings) -> Course? {
        let courses = (try? context.fetch(FetchDescriptor<Course>(sortBy: [SortDescriptor(\.order)]))) ?? []
        return courses.first { $0.remoteId == settings.selectedCourseId } ?? courses.first
    }

    private static func wordReminderRequests(in context: ModelContext, settings: UserSettings,
                                             maxCount: Int, now: Date) -> [UNNotificationRequest] {
        guard let course = currentCourse(in: context, settings: settings) else { return [] }
        let pool = WordReminderPlanner.pool(courseId: course.remoteId, in: context)
        let plan = WordReminderPlanner.plan(now: now,
                                            intervalMinutes: settings.wordReminderMinutes,
                                            wordsPerNotification: settings.wordsPerReminder,
                                            pool: pool,
                                            maxCount: maxCount)
        return plan.map { planned in
            UNNotificationRequest(identifier: planned.id,
                                  content: wordContent(planned.words, courseName: course.name.text),
                                  trigger: trigger(at: planned.date))
        }
    }

    /// Quiet (no sound) and grouped, so frequent reminders don't get in the way.
    private static func wordContent(_ words: [ReminderWord], courseName: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        // The body is always the words; the sheet can only change the title.
        content.title = MessageCatalog.text("word_reminder", values: ["course": courseName])?.title
            ?? "word_reminder_title".localizedFormat(courseName)
        content.body = WordReminderPlanner.body(for: words)
        content.threadIdentifier = "word-reminders"
        content.sound = nil
        return content
    }

    /// Developer menu: one word reminder `testDelay` seconds from now.
    /// - Returns: false when there are no words yet (no completed lesson, no hard word).
    @discardableResult
    static func sendWordReminderSample(in context: ModelContext, settings: UserSettings) -> Bool {
        guard let course = currentCourse(in: context, settings: settings) else { return false }
        let pool = WordReminderPlanner.pool(courseId: course.remoteId, in: context)
        let words = WordReminderPlanner.words(at: .now, intervalMinutes: settings.wordReminderMinutes,
                                              pool: pool, count: settings.wordsPerReminder)
        guard !words.isEmpty else { return false }
        addTestNotification(id: "debug-words", content: wordContent(words, courseName: course.name.text), after: testDelay)
        return true
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

    /// Developer menu: one notification of each kind, 10 / 15 / 20 seconds from now
    /// (lock the device or go to the home screen to see them).
    static func debugSendSamples() {
        let kinds: [NotificationPlanner.Kind] = [.reminder, .dueCards(12), .streakAtRisk(7)]
        for (index, kind) in kinds.enumerated() {
            addTestNotification(id: "debug-sample-\(index)", content: content(for: kind),
                                after: testDelay + TimeInterval(5 * index))
        }
    }

    // MARK: - Test notifications (developer menu)

    /// Long enough to leave the app (or lock the phone) before the test fires; a notification that
    /// fires while the app is open shows only as an in-app banner, not on the Lock Screen.
    static let testDelay: TimeInterval = 10

    /// Test notifications use their own ids ("debug-…"), so `reschedule` (which runs when the app
    /// goes to the background) doesn't remove them. While the app is open they show as banners too
    /// (see `NotificationDelegate`).
    private static func addTestNotification(id: String, content: UNNotificationContent, after seconds: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Developer menu: how iOS is set to show this app's notifications
    /// (a notification can be delivered but only land in Notification Center).
    static func debugSettingsSummary() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { s in
                func on(_ setting: UNNotificationSetting) -> String {
                    switch setting {
                    case .enabled: return "on"
                    case .disabled: return "OFF"
                    default: return "n/a"
                    }
                }
                let status: String
                switch s.authorizationStatus {
                case .authorized: status = "authorized"
                case .denied: status = "DENIED"
                case .notDetermined: status = "not asked"
                case .provisional: status = "PROVISIONAL (quiet: Notification Center only)"
                case .ephemeral: status = "ephemeral"
                @unknown default: status = "unknown"
                }
                let style: String
                switch s.alertStyle {
                case .banner: style = "banner"
                case .alert: style = "alert"
                default: style = "NONE"
                }
                continuation.resume(returning: [
                    "Permission: \(status)",
                    "Lock Screen: \(on(s.lockScreenSetting)) · Notification Center: \(on(s.notificationCenterSetting))",
                    "Banners: \(on(s.alertSetting)) · style \(style) · Sounds: \(on(s.soundSetting))",
                    "Scheduled Summary: \(s.scheduledDeliverySetting == .enabled ? "ON (delivered later, in the summary)" : "off")"
                ])
            }
        }
    }

    /// Developer menu: the scheduled notifications, earliest first ("dd/MM HH:mm · id").
    static func debugPendingSummary() async -> [String] {
        // Lines are built in the completion handler so only Sendable strings cross back.
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let formatter = DateFormatter()
                formatter.dateFormat = "dd/MM HH:mm:ss"
                let lines = requests
                    .compactMap { request -> (Date, String)? in
                        let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                            ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
                        guard let date else { return nil }
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
        // Texts from the "App Messages" sheet when published, else the built-in strings.
        let remote: (title: String, body: String?)?
        switch kind {
        case .reminder:
            remote = MessageCatalog.text("reminder")
            content.title = "reminder_title".localized()
            content.body = "reminder_body".localized()
        case .dueCards(let count):
            remote = MessageCatalog.text("review_due", values: ["count": "\(count)"])
            content.title = "reminder_review_title".localized()
            content.body = "reminder_review_body".localizedFormat(count)
        case .streakAtRisk(let days):
            remote = MessageCatalog.text("streak_risk", values: ["days": "\(days)"])
            content.title = "streak_risk_title".localized()
            content.body = "streak_risk_body".localizedFormat(days)
        }
        if let remote, let body = remote.body, !remote.title.isEmpty, !body.isEmpty {
            content.title = remote.title
            content.body = body
        }
        content.sound = .default
        return content
    }
}

/// Shows developer-menu test notifications even while the app is open (iOS hides notifications of
/// the app in the foreground by default). Planned reminders stay hidden while the learner is in the app.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix("debug-") ? [.banner, .list, .sound] : []
    }
}
