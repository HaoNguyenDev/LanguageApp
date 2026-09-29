//
//  OnboardingCoordinator.swift
//  LanguageApp
//

import SwiftUI

struct OnboardingCoordinator: View {
    @Environment(UserSettings.self) private var userSettings
    var navRouter: any NavRouterProtocol

    var body: some View {
        OnboardingView(onFinish: { courseId, goal, reminder in
            userSettings.selectedCourseId = courseId
            userSettings.dailyGoalXP = goal.xp
            userSettings.reminderEnabled = reminder
            if reminder {
                NotificationManager.scheduleDailyReminder(hour: userSettings.reminderHour,
                                                          minute: userSettings.reminderMinute)
            }
            userSettings.hasCompletedOnboarding = true
            navRouter.replaceLast(with: Router.Splash.home)
        })
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}
