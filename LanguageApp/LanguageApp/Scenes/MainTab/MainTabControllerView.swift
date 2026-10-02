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
    @Namespace private var tabSelection

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

    /// Floating glass capsule like iOS 26 apps (e.g. Telegram): translucent bar, the selected tab
    /// sits in a soft pill that slides between tabs and is tinted with the accent color.
    @ViewBuilder
    private func tabBar() -> some View {
        HStack(spacing: 0) {
            ForEach(TabType.allTabs, id: \.self) { tab in
                tabItem(tab: tab, isSelected: selectedTab == tab.rawValue)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .modifier(TabBarGlassBackground())
    }

    @ViewBuilder
    private func tabItem(tab: TabType, isSelected: Bool) -> some View {
        let theme = userSettings.theme
        let color = isSelected ? theme.tabBarSelectedColor : theme.tabBarUnselectedColor
        Button {
            if selectedTab != tab.rawValue { FeedbackService.tap() }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = tab.rawValue
            }
        } label: {
            VStack(spacing: 3) {
                (isSelected ? tab.iconSelected : tab.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .symbolEffect(.bounce, value: isSelected)
                    .foregroundStyle(color)
                Text(tab.title)
                    .setFont(isSelected ? .bold : .medium, size: 10, color: color)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    Capsule()
                        .fill(theme.tabBarSelectedBgColor)
                        .matchedGeometryEffect(id: "selectedTab", in: tabSelection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

}

/// Liquid Glass on iOS 26, a blurred material with a hairline border and shadow before that.
private struct TabBarGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        }
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
