//
//  SplashCoordinator.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import Foundation
import SwiftUI

extension Router {
    enum Splash: Routable {
        case onboarding
        case home

        var id: String {
            switch self {
            case .onboarding: return "onboarding"
            case .home: return "home"
            }
        }
    }
}

struct SplashCoordinator: View, ScreenCoordinator {
    @Environment(UserSettings.self) private var userSettings
    typealias ScreenRouter = Router.Splash
    var navRouter: any NavRouterProtocol

    init(navRouter: any NavRouterProtocol) {
        self.navRouter = navRouter
    }

    var body: some View {
        getView()
            // Every route type pushed on `rootRouter.path` is registered here, at the root of the
            // NavigationStack, so it resolves no matter which screen is on top.
            .navigationDestination(for: ScreenRouter.self) { route in
                viewForRouter(router: route)
            }
            .navigationDestination(for: Router.MainTab.self) { route in
                MainTabRouteView(route: route, navRouter: navRouter)
            }
    }

    @ViewBuilder
    func getView() -> some View {
        SplashView(onFinished: {
            guard navRouter.path.isEmpty else { return }
            if userSettings.hasCompletedOnboarding {
                navRouter.push(ScreenRouter.home, animate: false)
            } else {
                navRouter.push(ScreenRouter.onboarding, animate: false)
            }
        })
    }

    @ViewBuilder
    func viewForRouter(router: ScreenRouter) -> some View {
        switch router {
        case .onboarding:
            OnboardingCoordinator(navRouter: navRouter)
        case .home:
            MainTabControllerView(navRouter: navRouter)
        }
    }
}
