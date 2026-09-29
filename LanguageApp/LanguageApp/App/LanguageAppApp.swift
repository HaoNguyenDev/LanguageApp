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

    private let modelContainer: ModelContainer

    init() {
        Logger.shared.isEnabled = true
        let container = PersistenceController.makeContainer()
        // Bundled content is small → import synchronously so the first screen has data.
        ContentImporter(context: container.mainContext).importBundledCourses()
        modelContainer = container
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
                    await premiumManager.start()
                }
        }
        .modelContainer(modelContainer)
    }
}
