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

    @State private var confirmCompleteAll = false

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
                    Button("Complete all lessons") { confirmCompleteAll = true }
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
                    toast("+100 XP")
                }
                Button("Build a 7-day streak") {
                    DebugActions.buildStreak(days: 7, in: modelContext)
                    toast("Streak: 7 days")
                }
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
        .confirmationDialog("Complete all lessons of this course?", isPresented: $confirmCompleteAll, titleVisibility: .visible) {
            Button("Complete all") {
                guard let course else { return }
                DebugActions.complete(course.orderedLessons, in: modelContext)
                toast("All lessons completed")
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func toast(_ message: String) {
        FeedbackService.tap()
        appState.showToast(item: UserMessageItem(message: message))
    }
}
