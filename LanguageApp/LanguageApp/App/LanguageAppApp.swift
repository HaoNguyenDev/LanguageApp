//
//  LanguageAppApp.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 29/09/2026.
//

import SwiftUI
import SwiftData

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
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer

    init() {
        Logger.shared.isEnabled = true
        // Bundled content is imported in `.task` below while the splash is shown
        // (the splash waits for `AppState.isContentReady`).
        modelContainer = PersistenceController.makeContainer()
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
                    appState.isContentReady = true
                    DailyQuestService.ensureTodayQuests(in: modelContainer.mainContext)
                    await premiumManager.start()
                    isPremiumReady = true
                    applyStreakFreezes()
                    checkAchievements()
                    NotificationManager.reschedule(in: modelContainer.mainContext, settings: userSettings)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard appState.isContentReady else { return }
                    switch phase {
                    case .active:
                        DailyQuestService.ensureTodayQuests(in: modelContainer.mainContext)
                        applyStreakFreezes()
                        checkAchievements()
                        NotificationManager.reschedule(in: modelContainer.mainContext, settings: userSettings)
                    case .background:
                        // After studying: today gets no more reminders, tomorrow's streak warning is planned.
                        NotificationManager.reschedule(in: modelContainer.mainContext, settings: userSettings)
                    default:
                        break
                    }
                }
        }
        .modelContainer(modelContainer)
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
