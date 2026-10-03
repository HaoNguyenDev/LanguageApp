//
//  SettingsView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 13/7/25.
//

import SwiftUI
import SwiftData

struct SettingsCoordinator: View {
    var navRouter: any NavRouterProtocol

    var body: some View {
        SettingsView(
            onChangeCourse: { navRouter.push(Router.MainTab.courseSelection, animate: true) },
            onOpenDeveloperMenu: { navRouter.push(Router.MainTab.developerMenu, animate: true) },
            onOpenPaywall: { navRouter.showSheet(RouterView(routable: Router.Study.paywall)) }
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct SettingsView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(PremiumManager.self) private var premium
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.order) private var courses: [Course]
    @Query private var activities: [DailyActivity]

    var onChangeCourse: VoidResult?
    var onOpenDeveloperMenu: VoidResult?
    var onOpenPaywall: VoidResult?

    @State private var showThemePicker = false
    @State private var showLanguagePicker = false
    @State private var showResetConfirm = false
    @State private var notificationPermission: NotificationManager.Permission = .allowed
    @State private var showPermissionAlert = false
    @Environment(\.scenePhase) private var scenePhase
    /// UI language picked in the sheet that equals the language being learned; confirmed after the sheet closes.
    @State private var pendingLanguage: LanguageCode?
    @State private var showSameLanguageAlert = false

    private var course: Course? {
        courses.first { $0.remoteId == userSettings.selectedCourseId } ?? courses.first
    }

    var body: some View {
        @Bindable var settings = userSettings
        let theme = userSettings.theme

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ScreenTitle(title: "settings".localized())

                premiumBanner

                section("section_learning".localized()) {
                    row(icon: "globe", title: "learning_language".localized(),
                        value: course?.name.text) {
                        onChangeCourse?()
                    }
                    Menu {
                        ForEach(DailyGoal.allCases) { goal in
                            Button("\(goal.minutesKey.localized()) · \(goal.xp) XP") {
                                userSettings.dailyGoalXP = goal.xp
                            }
                        }
                    } label: {
                        rowLabel(icon: "target", title: "daily_goal".localized(), value: "\(userSettings.dailyGoalXP) XP")
                    }
                    toggleRow(icon: "speaker.wave.2.fill", title: "sound_effects".localized(), isOn: $settings.soundEnabled)
                    toggleRow(icon: "waveform", title: "auto_play_audio".localized(), isOn: $settings.autoPlayAudio)
                    if notificationPermission == .denied,
                       userSettings.reminderEnabled || userSettings.wordRemindersEnabled {
                        NotificationPermissionBanner()
                    }
                    toggleRow(icon: "bell.fill", title: "daily_reminder".localized(),
                              isOn: Binding(get: { userSettings.reminderEnabled },
                                            set: { updateReminder(enabled: $0) }))
                    if userSettings.reminderEnabled {
                        toggleRow(icon: "sparkles", title: "smart_reminder_time".localized(),
                                  isOn: $settings.smartReminderTime)
                            .onChange(of: userSettings.smartReminderTime) { _, _ in
                                rescheduleNotifications()
                                checkNotificationPermission()
                            }
                        if let usual = usualTime {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .frame(width: 28)
                                    .foregroundStyle(theme.primaryColor)
                                Text("reminder_usual_time".localized())
                                    .setFont(.semibold, size: 16, color: theme.textColor)
                                Spacer()
                                Text(usual, format: .dateTime.hour().minute())
                                    .setFont(.semibold, size: 16, color: theme.secondaryTextColor)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                        } else {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .frame(width: 28)
                                    .foregroundStyle(theme.primaryColor)
                                Text("reminder_time".localized())
                                    .setFont(.semibold, size: 16, color: theme.textColor)
                                Spacer()
                                DatePicker("", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .onChange(of: userSettings.reminderTime) { _, _ in
                                rescheduleNotifications()
                                checkNotificationPermission()
                            }
                        }
                    }
                    WordReminderSettingsView(onPermissionDenied: {
                        notificationPermission = .denied
                        showPermissionAlert = true
                    })
                }

                section("section_app".localized()) {
                    row(icon: "character.bubble", title: "change_language_title".localized(),
                        value: LanguageCode(rawValue: userSettings.languageCode ?? "eng")?.title) {
                        showLanguagePicker = true
                    }
                    row(icon: "circle.lefthalf.filled", title: "change_theme_mode".localized(),
                        value: userSettings.colorSchemeOption.title) {
                        showThemePicker = true
                    }
                }

                section("section_data".localized()) {
                    row(icon: "arrow.counterclockwise", title: "reset_course_progress".localized(), value: nil, tint: theme.wrongColor) {
                        showResetConfirm = true
                    }
                    if premium.isPremium == false {
                        row(icon: "arrow.clockwise.circle", title: "restore_purchases".localized(), value: nil) {
                            Task { await premium.restorePurchases() }
                        }
                    }
                }

                if DebugSettings.isAvailable {
                    section("Developer") {
                        row(icon: "hammer.fill",
                            title: "Developer menu",
                            value: DebugSettings.shared.activeCount > 0 ? "\(DebugSettings.shared.activeCount) on" : nil) {
                            onOpenDeveloperMenu?()
                        }
                    }
                }

                Text(versionText)
                    .setFont(.regular, size: 13, color: theme.secondaryTextColor)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .tabBarSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .notificationPermissionAlert(isPresented: $showPermissionAlert)
        .task { notificationPermission = await NotificationManager.permission() }
        .onChange(of: scenePhase) { _, phase in
            // Back from iOS Settings: hide the warning once notifications are allowed again.
            if phase == .active {
                Task { notificationPermission = await NotificationManager.permission() }
            }
        }
        .sheet(isPresented: $showThemePicker) {
            ThemeChangeView()
                .presentationDetents([.height(410)])
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showLanguagePicker, onDismiss: {
            if pendingLanguage != nil { showSameLanguageAlert = true }
        }) {
            TitleListView(title: "change_language_title".localized(),
                          items: LanguageCode.allCases,
                          onDismiss: { showLanguagePicker = false },
                          onSelectItem: { _, item in
                if let code = item as? LanguageCode, code.rawValue != userSettings.languageCode {
                    if course?.isSameLanguage(asUILanguage: code.rawValue) == true {
                        pendingLanguage = code
                    } else {
                        applyLanguage(code)
                    }
                }
                showLanguagePicker = false
            })
            .presentationDetents([.height(520)])
            .presentationBackground(.clear)
        }
        .alert("same_language_title".localized(), isPresented: $showSameLanguageAlert, presenting: pendingLanguage) { code in
            Button("continue_anyway".localized()) {
                applyLanguage(code)
                pendingLanguage = nil
            }
            Button("cancel".localized(), role: .cancel) { pendingLanguage = nil }
        } message: { _ in
            let name = course?.name.text ?? ""
            Text("same_language_message".localizedFormat(name, name))
        }
        .confirmationDialog("reset_course_progress".localized(), isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("reset".localized(), role: .destructive) {
                if let course {
                    LessonCompletionService.resetProgress(of: course, in: modelContext)
                    appState.showToast(item: UserMessageItem(message: "progress_reset_done".localized()))
                }
            }
            Button("cancel".localized(), role: .cancel) {}
        } message: {
            Text("reset_course_message".localized())
        }
    }

    private var versionText: String {
        let base = "\("app_name".localized()) v\(Env.shared.getVersionApp())"
        return Env.shared.isDebugBuild ? "\(base) (\(Env.shared.getBuildNumber())) · Debug" : base
    }

    // MARK: - Premium

    @ViewBuilder
    private var premiumBanner: some View {
        let theme = userSettings.theme
        Button {
            if !premium.isPremium { onOpenPaywall?() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text((premium.isPremium ? "plus_active" : "upgrade_to_plus").localized())
                        .font(mainFont.bold(18))
                    Text("plus_short_benefits".localized())
                        .font(mainFont.regular(13))
                        .opacity(0.9)
                }
                Spacer()
                if !premium.isPremium { Image(systemName: "chevron.right") }
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(LinearGradient(colors: [theme.primaryColor, Color(hex: "#EC4899")],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - App language

    private func applyLanguage(_ code: LanguageCode) {
        LanguageManager.shared.setLanguage(language: code.getLanguage())
        userSettings.languageCode = code.rawValue
        // Notification texts are in the UI language.
        rescheduleNotifications()
    }

    // MARK: - Reminder

    private func updateReminder(enabled: Bool) {
        if enabled {
            Task {
                let granted = await NotificationManager.ensurePermission()
                userSettings.reminderEnabled = granted
                notificationPermission = granted ? .allowed : .denied
                if granted {
                    rescheduleNotifications()
                } else {
                    showPermissionAlert = true
                }
            }
        } else {
            userSettings.reminderEnabled = false
            // Keeps word reminders if they are on.
            rescheduleNotifications()
        }
    }

    /// A reminder option changed: warn when notifications are turned off in iOS Settings.
    private func checkNotificationPermission() {
        Task {
            notificationPermission = await NotificationManager.permission()
            if notificationPermission == .denied { showPermissionAlert = true }
        }
    }

    private func rescheduleNotifications() {
        NotificationManager.reschedule(in: modelContext, settings: userSettings)
    }

    /// The learner's usual study time while smart timing is on and known (shown instead of the time picker).
    private var usualTime: Date? {
        guard userSettings.smartReminderTime,
              let usual = NotificationPlanner.usualStudyTime(firstActiveTimes: activities.compactMap(\.firstActiveAt)) else {
            return nil
        }
        return Calendar.current.date(bySettingHour: usual.hour, minute: usual.minute, second: 0, of: .now)
    }

    // MARK: - Row builders

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .setFont(.bold, size: 13, color: userSettings.theme.secondaryTextColor)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(userSettings.theme.cardBgColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func rowLabel(icon: String, title: String, value: String?, tint: Color? = nil) -> some View {
        let theme = userSettings.theme
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(tint ?? theme.primaryColor)
            Text(title)
                .setFont(.semibold, size: 16, color: tint ?? theme.textColor)
            Spacer()
            if let value {
                Text(value)
                    .setFont(.regular, size: 15, color: theme.secondaryTextColor)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.secondaryTextColor)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    private func row(icon: String, title: String, value: String?, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(icon: icon, title: title, value: value, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        let theme = userSettings.theme
        return Toggle(isOn: isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 28)
                    .foregroundStyle(theme.primaryColor)
                Text(title)
                    .setFont(.semibold, size: 16, color: theme.textColor)
            }
        }
        .tint(theme.primaryColor)
        .padding(.horizontal, 16)
        .frame(height: 56)
    }
}

#Preview {
    SettingsView()
        .environment(UserSettings())
        .environment(PremiumManager())
        .environment(AppState())
        .modelContainer(PersistenceController.preview)
}
