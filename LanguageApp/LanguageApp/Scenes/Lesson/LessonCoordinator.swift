//
//  LessonCoordinator.swift
//  LanguageApp
//
//  Loads the lesson, builds exercises, and switches between the player and the result screen.
//

import SwiftUI
import SwiftData

struct LessonCoordinator: View {
    var navRouter: any NavRouterProtocol
    let lessonId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(UserSettings.self) private var userSettings
    @Environment(GamificationManager.self) private var gamification
    @Environment(PremiumManager.self) private var premium

    @State private var lesson: Lesson?
    @State private var viewModel: LessonSessionViewModel?
    @State private var result: LessonResult?
    @State private var showPaywall = false

    var body: some View {
        Group {
            if let result {
                LessonResultView(result: result, onContinue: close)
            } else if let viewModel, let lesson {
                LessonPlayerView(viewModel: viewModel,
                                 speechLocale: lesson.course?.speechLocale ?? "en-US",
                                 onClose: close,
                                 onGetPremium: { showPaywall = true })
                    .onChange(of: viewModel.phase) { _, phase in
                        if phase == .finished { finish(lesson: lesson, viewModel: viewModel) }
                    }
            } else {
                LoadingView(hideText: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .setDefaultBackground()
            }
        }
        .task { loadIfNeeded() }
        .sheet(isPresented: $showPaywall, onDismiss: {
            if premium.isPremium { viewModel?.resumeAfterRefill() }
        }) {
            PaywallView(onClose: { showPaywall = false })
        }
    }

    private func loadIfNeeded() {
        guard lesson == nil else { return }
        let id = lessonId
        let descriptor = FetchDescriptor<Lesson>(predicate: #Predicate { $0.remoteId == id })
        guard let found = try? modelContext.fetch(descriptor).first, let course = found.course else {
            Logger.shared.error("Lesson not found: \(lessonId)")
            close()
            return
        }

        let locale = course.speechLocale
        let debug = DebugSettings.shared
        let items = debug.limitLessonWords(found.sortedItems).map { StudyItem(item: $0, speechLocale: locale) }
        let pool = course.allItems.map { StudyItem(item: $0, speechLocale: locale) }
        let newIds = Set(found.sortedItems.filter { !$0.isLearned }.map(\.remoteId))

        var rng = SystemRandomNumberGenerator()
        let exercises = debug.lessonGenerator().makeLesson(items: items,
                                                       distractorPool: pool,
                                                       newWordIds: newIds,
                                                       using: &rng)
        let vm = LessonSessionViewModel(lessonTitle: found.title.text, exercises: exercises)
        let hearts = gamification
        let store = premium
        vm.onMistake = {
            hearts.loseHeart(isPremium: store.isPremium)
            return hearts.hasHearts(isPremium: store.isPremium)
        }
        lesson = found
        viewModel = vm
    }

    private func finish(lesson: Lesson, viewModel: LessonSessionViewModel) {
        guard result == nil else { return }
        let outcome = LessonCompletionService.complete(lesson: lesson,
                                                       accuracy: viewModel.accuracy,
                                                       dailyGoalXP: userSettings.dailyGoalXP,
                                                       mistakes: viewModel.mistakesByItemId,
                                                       in: modelContext)
        FeedbackService.celebrate(sound: userSettings.soundEnabled)
        withAnimation { result = outcome }
    }

    private func close() {
        navRouter.dismiss()
    }
}
