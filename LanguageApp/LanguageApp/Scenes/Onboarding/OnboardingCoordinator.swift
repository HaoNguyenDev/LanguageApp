//
//  OnboardingCoordinator.swift
//  LanguageApp
//

import SwiftUI

struct OnboardingCoordinator: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(\.modelContext) private var modelContext
    var navRouter: any NavRouterProtocol

    var body: some View {
        OnboardingView(onFinish: { courseId, goal, reminder in
            userSettings.selectedCourseId = courseId
            userSettings.dailyGoalXP = goal.xp
            userSettings.reminderEnabled = reminder
            if reminder {
                NotificationManager.reschedule(in: modelContext, settings: userSettings)
            }
            userSettings.hasCompletedOnboarding = true
            navRouter.replaceLast(with: Router.Splash.home)
        })
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}
