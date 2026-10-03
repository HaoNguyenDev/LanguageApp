//
//  AppCoordinator.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI
import SwiftData

extension Router {
    /// Modal flows presented from anywhere (full screen cover / sheet on the root router).
    enum Study: Routable {
        case lesson(lessonId: String)
        case checkpoint(unitId: String)
        case review(courseId: String, practice: Bool)
        case practiceWeakWords(courseId: String)
        case paywall
        case streak

        var id: String {
            switch self {
            case .lesson(let lessonId): return "lesson-\(lessonId)"
            case .checkpoint(let unitId): return "checkpoint-\(unitId)"
            case .review(let courseId, let practice): return "review-\(courseId)-\(practice)"
            case .practiceWeakWords(let courseId): return "practice-\(courseId)"
            case .paywall: return "paywall"
            case .streak: return "streak"
            }
        }
    }
}

struct AppCoordinator: View {
    @Environment(AppSettings.self) var appSettings
    @Environment(AppState.self) var appState
    @Environment(UserSettings.self) var userSettings
    @Environment(\.colorScheme) var systemColorScheme

    @State var rootRouter = NavRouter()
    @State private var isShowBlockingView: Bool = false

    private static let expectedBundleId = "com.haonguyen.apps.LanguageApp"

    var body: some View {
        Group {
            if isShowBlockingView {
                blockingView
            } else {
                contentView
            }
        }
        .onAppear {
            userSettings.setColorScheme(userSettings.colorSchemeOption, systemColorScheme: systemColorScheme)
        }
        .onChange(of: systemColorScheme) { _, newValue in
            userSettings.setColorScheme(userSettings.colorSchemeOption, systemColorScheme: newValue)
        }
        .preferredColorScheme(preferredScheme)
        .task { startCheckingApp() }
    }

    private var preferredScheme: ColorScheme? {
        switch userSettings.colorSchemeOption {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func startCheckingApp() {
        // Simple anti-repackaging check inherited from SwiftUI-BaseApp.
        isShowBlockingView = Bundle.main.bundleIdentifier != Self.expectedBundleId
    }

    @ViewBuilder
    var blockingView: some View {
        Text("device_restricted".localized())
            .setFont(.bold, size: 20, color: userSettings.theme.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .setDefaultBackground()
    }

    @ViewBuilder
    var contentView: some View {
        ZStack {
            if appSettings.isMaintenance {
                maintenanceView
            } else {
                NavigationStack(path: $rootRouter.path) {
                    SplashCoordinator(navRouter: rootRouter)
                }
                .tint(userSettings.theme.primaryColor)
                .sheet(item: $rootRouter.sheet) { sheet in
                    showSheet(routable: sheet.routable)
                }
                .fullScreenCover(item: $rootRouter.fullScreenCover) { cover in
                    showFullScreen(routable: cover.routable)
                }
                .onChange(of: rootRouter.fullScreenCover?.id) { _, id in
                    appState.isStudying = id != nil
                }
            }
            if appState.isShowLoading {
                loadingView
            }
            toastView(appState.userMessageState.toastMessages.first)
            informView(appState.userMessageState.informMessage)
            alertView(appState.userMessageState.alert)
        }
    }

    @ViewBuilder
    var maintenanceView: some View {
        VStack(spacing: 12) {
            Text("system_maintenance".localized())
                .setFont(.semibold, size: 32, color: userSettings.theme.textColor)
            Text("maintenance_message".localized())
                .setFont(.regular, size: 17, color: userSettings.theme.textColor)
        }
        .multilineTextAlignment(.center)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
    }
}

// MARK: - Modal routing
extension AppCoordinator {
    @ViewBuilder
    func showSheet(routable: any Routable) -> some View {
        switch routable {
        case Router.Study.paywall:
            PaywallCoordinator(navRouter: rootRouter)
        case Router.Study.streak:
            StreakCoordinator(navRouter: rootRouter)
        default:
            Text("OOPS!\nThis route is not implemented AppCoordinator showSheet function yet.")
        }
    }

    @ViewBuilder
    func showFullScreen(routable: any Routable) -> some View {
        switch routable {
        case Router.Study.lesson(let lessonId):
            LessonCoordinator(navRouter: rootRouter, lessonId: lessonId)
        case Router.Study.checkpoint(let unitId):
            UnitCheckpointCoordinator(navRouter: rootRouter, unitId: unitId)
        case Router.Study.review(let courseId, let practice):
            ReviewSessionCoordinator(navRouter: rootRouter, courseId: courseId, practiceMode: practice)
        case Router.Study.practiceWeakWords(let courseId):
            PracticeCoordinator(navRouter: rootRouter, courseId: courseId)
        case Router.Study.paywall:
            PaywallCoordinator(navRouter: rootRouter)
        default:
            Text("OOPS!\nThis route is not implemented at AppCoordinator showFullScreen function yet.")
        }
    }
}

// MARK: - Global messages (toast / inform / alert)
extension AppCoordinator {
    @ViewBuilder
    private var loadingView: UserInformView {
        let loadingMessage = UserMessageItem(animationName: "ic_boost_loading",
                                             title: "loading".localized(),
                                             message: "loading_message".localized())
        UserInformView(message: loadingMessage)
    }

    @ViewBuilder
    private func toastView(_ message: UserMessageItem?) -> some View {
        Group {
            if let message = message {
                UserMessageView(message: message) { _ in
                    appState.userMessageState.hide()
                }
                .id(message.id)
            }
        }
    }

    @ViewBuilder
    private func informView(_ message: UserMessageItem?) -> some View {
        Group {
            if let message {
                UserInformView(message: message)
            }
        }
    }

    @ViewBuilder
    private func alertView(_ message: UserMessageItem?) -> some View {
        Group {
            if let message {
                let action = InformAction(title: message.actionTitle ?? "close".localized(),
                                          callback: {
                    appState.userMessageState.hideAlert()
                })
                UserInformView(message: message, primaryAction: action)
            }
        }
    }
}

#Preview {
    AppCoordinator()
        .environment(UserSettings())
        .environment(AppSettings())
        .environment(AppState())
        .environment(GamificationManager())
        .environment(PremiumManager())
        .environment(SpeechService())
        .modelContainer(PersistenceController.preview)
}
