//
//  DeveloperMenuView.swift
//  LanguageApp
//
//  Settings ▸ Developer (Debug builds only). Developer tool → English only, system Form style.
//

import SwiftUI
import SwiftData
import UIKit

struct DeveloperMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserSettings.self) private var userSettings
    @Environment(GamificationManager.self) private var gamification
    @Environment(PremiumManager.self) private var premium
    @Environment(AppState.self) private var appState
    @Query(sort: \Course.order) private var courses: [Course]

    @State private var pendingAction: ConfirmAction?
    @State private var plannedNotifications: [String] = []

    /// Destructive developer actions that ask for confirmation first.
    private enum ConfirmAction: Identifiable {
        case completeAllLessons, resetAllCourses, resetEverything
        var id: Self { self }

        var title: String {
            switch self {
            case .completeAllLessons: return "Complete all lessons of this course?"
            case .resetAllCourses: return "Reset all courses?"
            case .resetEverything: return "Reset everything?"
            }
        }

        var message: String {
            switch self {
            case .completeAllLessons: return "Every lesson is marked completed and its words go into review."
            case .resetAllCourses: return "Lessons and review progress of all 6 courses go back to the start. XP, streak and quests are kept."
            case .resetEverything: return "All courses, XP, streak, daily activity, quests, streak freezes and hearts are reset – like a fresh install. Settings and onboarding are kept."
            }
        }

        var buttonTitle: String {
            switch self {
            case .completeAllLessons: return "Complete all"
            case .resetAllCourses: return "Reset all courses"
            case .resetEverything: return "Reset everything"
            }
        }
    }

    private var course: Course? {
        courses.first { $0.remoteId == userSettings.selectedCourseId } ?? courses.first
    }

    var body: some View {
        @Bindable var debug = DebugSettings.shared
        Form {
            Section {
                Toggle("Unlock all lessons", isOn: $debug.unlockAllLessons)
                Toggle("Unlimited hearts", isOn: $debug.unlimitedHearts)
                Picker("Subscription", selection: $debug.premiumOverride) {
                    ForEach(DebugSettings.PremiumOverride.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Access")
            } footer: {
                Text("StoreKit entitlement: \(premium.hasActiveSubscription ? "Plus" : "Free") · effective: \(premium.isPremium ? "Plus" : "Free")")
            }

            Section {
                Picker("Questions", selection: $debug.questionKind) {
                    ForEach(DebugSettings.QuestionKind.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Skip new-word cards", isOn: $debug.skipIntroCards)
                Toggle("Skip match pairs", isOn: $debug.skipMatchPairs)
                Toggle("Short lessons (3 words)", isOn: $debug.shortLessons)
                Toggle("Show answers", isOn: $debug.showAnswers)
            } header: {
                Text("Lessons")
            } footer: {
                Text("Applies to lessons and \"Practice weak words\" started after the change.")
            }

            Section("Hearts") {
                LabeledContent("Hearts", value: "\(gamification.hearts) / \(GamificationManager.maxHearts)")
                Button("Refill hearts") {
                    gamification.refillAll()
                    toast("Hearts refilled")
                }
                Button("Empty hearts") {
                    gamification.debugSetHearts(0)
                    toast("Hearts set to 0")
                }
            }

            if let course {
                Section {
                    Button("Complete current unit") {
                        let lessons = DebugActions.currentUnitLessons(of: course)
                        DebugActions.complete(lessons, in: modelContext)
                        toast("Completed \(lessons.count) lessons")
                    }
                    Button("Complete all lessons") { pendingAction = .completeAllLessons }
                    Button("Pass checkpoints of completed units") {
                        let count = DebugActions.passUnlockedCheckpoints(of: course, in: modelContext)
                        toast("\(count) checkpoint(s) passed")
                    }
                    Button("Reset course progress", role: .destructive) {
                        LessonCompletionService.resetProgress(of: course, in: modelContext)
                        toast("Course progress reset")
                    }
                } header: {
                    Text("Progress · \(course.name.text)")
                } footer: {
                    Text("\(course.completedLessonCount) / \(course.orderedLessons.count) lessons completed")
                }

                Section("Review & practice") {
                    Button("Make all learned words due now") {
                        let count = DebugActions.makeAllDue(in: course, context: modelContext)
                        toast("\(count) words due")
                    }
                    Button("Mark 8 random words weak") {
                        let count = DebugActions.markRandomWordsWeak(in: course, context: modelContext)
                        toast("\(count) words marked weak")
                    }
                }
            }

            Section("Stats") {
                Button("+100 XP today") {
                    DebugActions.addXP(100, in: modelContext)
                    DailyQuestService.claimCompleted(in: modelContext, dailyGoalXP: userSettings.dailyGoalXP)
                    toast("+100 XP")
                }
                Button("Build a 7-day streak") {
                    DebugActions.buildStreak(days: 7, in: modelContext)
                    toast("Streak: 7 days")
                }
            }

            Section {
                Button("Start today over") {
                    DebugActions.startTodayOver(in: modelContext)
                    toast("Today reset – quests start from 0")
                }
                Button("Next quest set") {
                    let kinds = DebugActions.nextQuestSet(in: modelContext)
                    toast(kinds.map(\.rawValue).joined(separator: ", "))
                }
            } header: {
                Text("Daily quests")
            } footer: {
                Text("Start today over clears today's XP, lessons, reviews, quests and rewards (earlier days are kept). Next quest set switches today's quests without paying rewards twice.")
            }

            Section {
                Button("Give 2 streak freezes") {
                    gamification.debugSetStreakFreezes(GamificationManager.maxStreakFreezes)
                    toast("Streak freezes: \(GamificationManager.maxStreakFreezes)")
                }
                Button("Remove streak freezes") {
                    gamification.debugSetStreakFreezes(0)
                    toast("Streak freezes: 0")
                }
                Button("7-day streak, missed yesterday") {
                    DebugActions.buildStreakMissingYesterday(in: modelContext)
                    gamification.streakLostAfterDayKey = nil
                    toast("Yesterday missed – apply freezes or reopen the app")
                }
                Button("Apply streak freezes now") {
                    let days = StreakFreezeService.applyIfNeeded(in: modelContext,
                                                                 gamification: gamification,
                                                                 isPremium: premium.isPremium)
                    toast(days > 0 ? "Frozen \(days) day(s)" : "Nothing frozen")
                }
            } header: {
                Text("Streak freeze")
            } footer: {
                Text("Owned: \(gamification.streakFreezes) · XP spent: \(gamification.spentXP)")
            }

            Section {
                Button("Send one of each notification in 5 s") {
                    Task {
                        guard await NotificationManager.requestAuthorization() else {
                            toast("Notifications are not allowed")
                            return
                        }
                        NotificationManager.debugSendSamples()
                        toast("Go to the home screen to see them")
                    }
                }
                Button("Re-plan notifications now") {
                    NotificationManager.reschedule(in: modelContext, settings: userSettings)
                    Task { plannedNotifications = await NotificationManager.debugPendingSummary() }
                }
                ForEach(plannedNotifications, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text(userSettings.reminderEnabled
                     ? "\(plannedNotifications.count) planned. Reminders are re-planned when the app becomes active or goes to the background."
                     : "Daily reminder is off in Settings – nothing is planned.")
            }
            .task { plannedNotifications = await NotificationManager.debugPendingSummary() }

            Section {
                Button("Reset all courses", role: .destructive) { pendingAction = .resetAllCourses }
                Button("Reset everything", role: .destructive) { pendingAction = .resetEverything }
            } header: {
                Text("Reset")
            } footer: {
                Text("Reset all courses: lessons + review progress of every course. Reset everything: also XP, streak, quests, streak freezes and hearts.")
            }

            Section {
                Button("Show onboarding on next launch") {
                    userSettings.hasCompletedOnboarding = false
                    toast("Restart the app to see onboarding")
                }
                Button("Reset developer switches", role: .destructive) {
                    debug.resetAll()
                    toast("Developer switches reset")
                }
            } header: {
                Text("App")
            }

            Section("Build info") {
                LabeledContent("Configuration", value: Env.shared.buildConfiguration)
                LabeledContent("Version", value: "\(Env.shared.getVersionApp()) (\(Env.shared.getBuildNumber()))")
                LabeledContent("Bundle id", value: Bundle.main.bundleIdentifier ?? "-")
                LabeledContent("iOS", value: UIDevice.current.systemVersion)
                LabeledContent("UI language", value: userSettings.languageCode ?? "-")
                if let course {
                    LabeledContent("Course", value: "\(course.remoteId) · content v\(course.contentVersion)")
                    LabeledContent("Words learned", value: "\(course.allItems.filter(\.isLearned).count) / \(course.allItems.count)")
                }
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog(pendingAction?.title ?? "",
                            isPresented: Binding(get: { pendingAction != nil },
                                                 set: { if !$0 { pendingAction = nil } }),
                            titleVisibility: .visible,
                            presenting: pendingAction) { action in
            Button(action.buttonTitle, role: action == .completeAllLessons ? nil : .destructive) {
                perform(action)
            }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.message)
        }
    }

    private func perform(_ action: ConfirmAction) {
        switch action {
        case .completeAllLessons:
            guard let course else { return }
            DebugActions.complete(course.orderedLessons, in: modelContext)
            toast("All lessons completed")
        case .resetAllCourses:
            DebugActions.resetAllCourses(in: modelContext)
            toast("All courses reset")
        case .resetEverything:
            DebugActions.resetEverything(in: modelContext)
            gamification.debugResetAll()
            DailyQuestService.ensureTodayQuests(in: modelContext)
            toast("Everything reset")
        }
    }

    private func toast(_ message: String) {
        FeedbackService.tap()
        appState.showToast(item: UserMessageItem(message: message))
    }
}
