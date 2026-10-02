//
//  LearnCoordinator.swift
//  LanguageApp
//

import SwiftUI

struct LearnCoordinator: View {
    var navRouter: any NavRouterProtocol
    @Environment(AppState.self) private var appState
    @Environment(GamificationManager.self) private var gamification
    @Environment(PremiumManager.self) private var premium

    var body: some View {
        LearnView(
            onStartLesson: { lesson in
                guard checkHearts() else { return }
                navRouter.showFullScreenCover(RouterView(routable: Router.Study.lesson(lessonId: lesson.remoteId)))
            },
            onStartCheckpoint: { unit in
                guard checkHearts() else { return }
                navRouter.showFullScreenCover(RouterView(routable: Router.Study.checkpoint(unitId: unit.remoteId)))
            },
            onLocked: { messageKey in
                appState.showToast(item: UserMessageItem(message: messageKey.localized()))
            },
            onChangeCourse: {
                navRouter.push(Router.MainTab.courseSelection, animate: true)
            },
            onOpenPaywall: {
                navRouter.showSheet(RouterView(routable: Router.Study.paywall))
            },
            onOpenStreak: {
                navRouter.showSheet(RouterView(routable: Router.Study.streak))
            }
        )
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Lessons and checkpoints need a heart; otherwise the paywall opens.
    private func checkHearts() -> Bool {
        gamification.refreshHearts()
        guard gamification.hasHearts(isPremium: premium.isPremium) else {
            appState.showToast(item: UserMessageItem(title: "out_of_hearts_title".localized(),
                                                     message: "out_of_hearts_message".localized()))
            navRouter.showSheet(RouterView(routable: Router.Study.paywall))
            return false
        }
        return true
    }
}
