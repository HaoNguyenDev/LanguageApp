//
//  NotificationManager.swift
//  LanguageApp
//
//  Daily study reminder (local notification) – the #1 retention lever for streak apps.
//

import Foundation
import UserNotifications

enum NotificationManager {
    private static let reminderId = "daily_study_reminder"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Logger.shared.error("Notification auth failed: \(error)")
            return false
        }
    }

    static func scheduleDailyReminder(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderId])

        let content = UNMutableNotificationContent()
        content.title = "reminder_title".localized()
        content.body = "reminder_body".localized()
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: reminderId, content: content, trigger: trigger))
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId])
    }
}
