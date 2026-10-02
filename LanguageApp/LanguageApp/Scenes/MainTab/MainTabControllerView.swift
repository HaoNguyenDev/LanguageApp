//
//  MainTabControllerView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 13/7/25.
//

import SwiftUI
import SwiftData
import UIKit

enum TabType: Int, CaseIterable {
    case learn = 0
    case review = 1
    case profile = 2
    case settings = 3

    static let allTabs: [TabType] = [.learn, .review, .profile, .settings]

    var title: String {
        switch self {
        case .learn: return "tab_learn".localized()
        case .review: return "tab_review".localized()
        case .profile: return "tab_profile".localized()
        case .settings: return "tab_settings".localized()
        }
    }

    var icon: Image {
        switch self {
        case .learn: return Image(systemName: "house")
        case .review: return Image(systemName: "rectangle.stack")
        case .profile: return Image(systemName: "chart.bar")
        case .settings: return Image(systemName: "gearshape")
        }
    }

    var iconSelected: Image {
        switch self {
        case .learn: return Image(systemName: "house.fill")
        case .review: return Image(systemName: "rectangle.stack.fill")
        case .profile: return Image(systemName: "chart.bar.fill")
        case .settings: return Image(systemName: "gearshape.fill")
        }
    }
}

extension Router {
    /// Screens pushed on top of the tab bar.
    enum MainTab: Routable {
        case courseSelection
        case wordList(courseId: String)
        case developerMenu

        var id: String {
            switch self {
            case .courseSelection: return "courseSelection"
            case .wordList(let courseId): return "wordList-\(courseId)"
            case .developerMenu: return "developerMenu"
            }
        }
    }
}

struct MainTabControllerView: View {
    var navRouter: any NavRouterProtocol
    @Environment(UserSettings.self) var userSettings
    @Environment(GamificationManager.self) var gamification
    @Environment(\.scenePhase) private var scenePhase
    @State var selectedTab = TabType.learn.rawValue

    init(navRouter: any NavRouterProtocol) {
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance

        self.navRouter = navRouter
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Custom tab container (no system TabView): the native tab bar would otherwise show
            // placeholder "?" icons on iOS 26 because our tabs have no `.tabItem`.
            // All tabs stay alive so each keeps its scroll position/state.
            ZStack {
                tabContent(.learn) { LearnCoordinator(navRouter: navRouter) }
                tabContent(.review) { ReviewCoordinator(navRouter: navRouter) }
                tabContent(.profile) { ProfileCoordinator(navRouter: navRouter) }
                tabContent(.settings) { SettingsCoordinator(navRouter: navRouter) }
            }

            tabBar()
                .padding(.horizontal, 24)
                .padding(.bottom, 0)
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: .showReviewTab)) { _ in
            selectedTab = TabType.review.rawValue
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { gamification.refreshHearts() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func tabContent<Content: View>(_ tab: TabType, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = selectedTab == tab.rawValue
        return content()
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }

    @ViewBuilder
    private func tabBar() -> some View {
        HStack {
            ForEach(TabType.allTabs, id: \.self) { tab in
                tabItem(tab: tab, isSelected: selectedTab == tab.rawValue)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 68)
        .background(
            userSettings.theme.subviewBgColor
                .clipShape(RoundedRectangle(cornerRadius: 34))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private func tabItem(tab: TabType, isSelected: Bool) -> some View {
        Button {
            if selectedTab != tab.rawValue { FeedbackService.tap() }
            selectedTab = tab.rawValue
        } label: {
            VStack(spacing: 4) {
                (isSelected ? tab.iconSelected : tab.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                    .foregroundStyle(isSelected ? userSettings.theme.mainTabSelectedTextColor : userSettings.theme.mainTabUnselectedTextColor)
                Text(tab.title)
                    .setFont(isSelected ? .bold : .regular, size: 10,
                             color: isSelected ? userSettings.theme.mainTabSelectedTextColor : userSettings.theme.mainTabUnselectedTextColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

/// Screens pushed on top of the tab bar (`Router.MainTab`).
/// The destination is registered at the root of the NavigationStack (`SplashCoordinator`), not on
/// `MainTabControllerView`: that view is itself a pushed destination, and a `navigationDestination`
/// declared there is not always visible to the stack, so a push showed the yellow warning icon.
struct MainTabRouteView: View {
    let route: Router.MainTab
    var navRouter: any NavRouterProtocol

    var body: some View {
        switch route {
        case .courseSelection:
            CourseSelectionCoordinator(navRouter: navRouter)
        case .wordList(let courseId):
            WordListCoordinator(navRouter: navRouter, courseId: courseId)
        case .developerMenu:
            DeveloperMenuView()
        }
    }
}

extension View {
    /// Space for the floating tab bar.
    func tabBarSafeArea() -> some View {
        safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
    }
}

#Preview {
    MainTabControllerView(navRouter: NavRouter())
        .environment(UserSettings())
        .environment(GamificationManager())
        .environment(PremiumManager())
        .environment(SpeechService())
        .environment(AppState())
        .modelContainer(PersistenceController.preview)
}
