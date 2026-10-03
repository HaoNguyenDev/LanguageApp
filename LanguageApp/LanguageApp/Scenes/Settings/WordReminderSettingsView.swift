//
//  WordReminderSettingsView.swift
//  LanguageApp
//
//  Settings rows for word reminders: on / off, how often, how many words per notification.
//

import SwiftUI
import SwiftData

struct WordReminderSettingsView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(\.modelContext) private var modelContext
    /// Re-read the word pool when lessons / reviews change.
    @Query private var activities: [DailyActivity]

    /// Notifications are turned off in iOS Settings → the parent shows the "Open Settings" alert.
    var onPermissionDenied: VoidResult?

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 0) {
            Toggle(isOn: Binding(get: { userSettings.wordRemindersEnabled }, set: { setEnabled($0) })) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .frame(width: 28)
                        .foregroundStyle(theme.primaryColor)
                    Text("word_reminders".localized())
                        .setFont(.semibold, size: 16, color: theme.textColor)
                }
            }
            .tint(theme.primaryColor)
            .padding(.horizontal, 16)
            .frame(height: 56)

            if userSettings.wordRemindersEnabled {
                Menu {
                    ForEach(WordReminderPlanner.intervalOptions, id: \.self) { minutes in
                        Button(Self.intervalTitle(minutes)) {
                            userSettings.wordReminderMinutes = minutes
                            reschedule()
                            checkPermission()
                        }
                    }
                } label: {
                    row(icon: "timer", title: "word_reminder_interval".localized(),
                        value: Self.intervalTitle(userSettings.wordReminderMinutes))
                }

                Menu {
                    ForEach(WordReminderPlanner.wordCountOptions, id: \.self) { count in
                        Button("word_reminder_words_value".localizedFormat(count)) {
                            userSettings.wordsPerReminder = count
                            reschedule()
                            checkPermission()
                        }
                    }
                } label: {
                    row(icon: "list.bullet", title: "word_reminder_count".localized(),
                        value: "word_reminder_words_value".localizedFormat(userSettings.wordsPerReminder))
                }

                Text(footer)
                    .setFont(.regular, size: 13, color: theme.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
    }

    private var footer: String {
        let explanation = "word_reminder_footer".localizedFormat(WordReminderPlanner.activeStartHour,
                                                                  WordReminderPlanner.activeEndHour)
        guard let course = NotificationManager.currentCourse(in: modelContext, settings: userSettings) else {
            return explanation
        }
        let count = WordReminderPlanner.pool(courseId: course.remoteId, in: modelContext).count
        let status = count == 0
            ? "word_reminder_empty".localized()
            : "word_reminder_pool".localizedFormat(count, course.name.text)
        return explanation + "\n" + status
    }

    static func intervalTitle(_ minutes: Int) -> String {
        "word_reminder_minutes".localizedFormat(minutes)
    }

    private func setEnabled(_ enabled: Bool) {
        guard enabled else {
            userSettings.wordRemindersEnabled = false
            reschedule()
            return
        }
        Task {
            let granted = await NotificationManager.ensurePermission()
            userSettings.wordRemindersEnabled = granted
            if granted {
                reschedule()
            } else {
                onPermissionDenied?()
            }
        }
    }

    private func checkPermission() {
        Task {
            if await NotificationManager.permission() == .denied { onPermissionDenied?() }
        }
    }

    private func reschedule() {
        NotificationManager.reschedule(in: modelContext, settings: userSettings)
    }

    private func row(icon: String, title: String, value: String) -> some View {
        let theme = userSettings.theme
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(theme.primaryColor)
            Text(title)
                .setFont(.semibold, size: 16, color: theme.textColor)
            Spacer()
            Text(value)
                .setFont(.regular, size: 15, color: theme.secondaryTextColor)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.secondaryTextColor)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .contentShape(Rectangle())
    }
}
