//
//  LanguageAppApp.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 29/09/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct LanguageAppApp: App {
    @State private var userSettings = UserSettings()
    @State private var appSettings = AppSettings()
    @State private var appState = AppState()
    @State private var languageManager = LanguageManager.shared
    @State private var gamification = GamificationManager()
    @State private var premiumManager = PremiumManager()
    @State private var speechService = SpeechService()
    /// Streak freezes are applied only once the Plus entitlement is known.
    @State private var isPremiumReady = false
    /// When the app went to the background (welcome-back toast after a long enough break).
    @State private var backgroundedAt: Date?
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer

    init() {
        Logger.shared.isEnabled = true
        // Bundled content is imported in `.task` below while the splash is shown
        // (the splash waits for `AppState.isContentReady`).
        modelContainer = PersistenceController.makeContainer()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .environment(appState)
                .environment(appSettings)
                .environment(userSettings)
                .environment(languageManager)
                .environment(gamification)
                .environment(premiumManager)
                .environment(speechService)
                .task {
                    Logger.shared.info("UI language: \(userSettings.languageCode ?? "")")
                    await ContentImporter(context: modelContainer.mainContext).importBundledCoursesInSteps()
                    // Content downloaded during the last session is applied while the splash is shown.
                    let appliedAtLaunch = applyRemoteContent()
                    appState.isContentReady = true
                    DailyQuestService.ensureTodayQuests(in: modelContainer.mainContext)
                    await premiumManager.start()
                    isPremiumReady = true
                    applyStreakFreezes()
                    checkAchievements()
                    NotificationManager.reschedule(in: modelContainer.mainContext, settings: userSettings)
                    // Every launch checks for new content (foreground returns are throttled);
                    // without anything new the learner gets a welcome-back toast instead.
                    let updated = await checkRemoteContent(force: true)
                    if !appliedAtLaunch && !updated { showWelcomeBack() }
                }
                .onChange(of: appState.isStudying) { _, isStudying in
                    if !isStudying { applyRemoteContent() }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard appState.isContentReady else { return }
                    switch phase {
                    case .active:
                        DailyQuestService.ensureTodayQuests(in: modelContainer.mainContext)
                        applyStreakFreezes()
                        checkAchievements()
                        NotificationManager.reschedule(in: modelContainer.mainContext, settings: userSettings)
                        let awayLongEnough = backgroundedAt.map { Date.now.timeIntervalSince($0) >= Self.welcomeBackAfter } ?? false
                        backgroundedAt = nil
                        Task {
                            let updated = await checkRemoteContent(force: awayLongEnough)
                            if awayLongEnough && !updated { showWelcomeBack() }
                        }
                    case .background:
                        backgroundedAt = .now
                        // After studying: today gets no more reminders, tomorrow's streak warning is planned.
                        NotificationManager.reschedule(in: modelContainer.mainContext, settings: userSettings)
                    default:
                        break
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    /// Time away before returning to the app counts as "coming back" (welcome toast, content check).
    private static let welcomeBackAfter: TimeInterval = 30 * 60

    /// Downloads newer course content (and app messages), then applies it unless a lesson is open.
    /// - Parameter force: ignore the foreground throttle (cold launch, back after a break).
    /// - Returns: true when new content was downloaded (applied now or after the lesson).
    @discardableResult
    private func checkRemoteContent(force: Bool = false) async -> Bool {
        let result = await RemoteContentService.checkForUpdates(
            installed: RemoteContentService.installedVersions(in: modelContainer.mainContext),
            channel: DebugSettings.shared.effectiveContentChannel,
            force: force)
        guard case .downloaded = result else { return false }
        applyRemoteContent()
        return true
    }

    /// A friendly "welcome back" / encouragement toast (texts from the App Messages sheet).
    private func showWelcomeBack() {
        guard userSettings.hasCompletedOnboarding, !appState.isStudying else { return }
        appState.showToast(item: MessageCatalog.welcomeToast(in: modelContainer.mainContext, settings: userSettings))
    }

    /// Imports downloaded course files (keeps progress) and tells the learner what's new.
    /// Waits while a lesson / review is open.
    @discardableResult
    private func applyRemoteContent() -> Bool {
        guard !appState.isStudying else { return false }
        let context = modelContainer.mainContext
        let course = NotificationManager.currentCourse(in: context, settings: userSettings)
        let before = RemoteContentService.counts(of: course)
        let updated = RemoteContentService.applyPending(in: context)
        guard !updated.isEmpty else { return false }
        DailyQuestService.ensureTodayQuests(in: context)
        NotificationManager.reschedule(in: context, settings: userSettings)

        // About the course being learned when it was updated, otherwise a general line.
        let toast = RemoteContentService.updateToast(
            courseName: course.flatMap { updated.contains($0.remoteId) ? $0.name.text : nil },
            before: before,
            after: RemoteContentService.counts(of: course))
        appState.showToast(item: UserMessageItem(title: toast.title, message: toast.message).readable())
        return true
    }

    /// Unlocks achievements reached outside lessons (e.g. after an update that adds new ones).
    private func checkAchievements() {
        guard appState.isContentReady else { return }
        let new = AchievementService.checkNew(in: modelContainer.mainContext)
        guard !new.isEmpty else { return }
        appState.showToast(item: AchievementService.toastItem(for: new))
    }

    /// Covers missed days with streak freezes and tells the learner.
    private func applyStreakFreezes() {
        guard appState.isContentReady, isPremiumReady else { return }
        let days = StreakFreezeService.applyIfNeeded(in: modelContainer.mainContext,
                                                     gamification: gamification,
                                                     isPremium: premiumManager.isPremium)
        guard days > 0 else { return }
        appState.showToast(item: UserMessageItem(title: "streak_freeze_used_title".localized(),
                                                 message: "streak_freeze_used_message".localized()))
    }
}
