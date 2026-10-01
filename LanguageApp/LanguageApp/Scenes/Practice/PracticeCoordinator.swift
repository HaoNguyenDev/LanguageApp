//
//  PracticeCoordinator.swift
//  LanguageApp
//
//  "Practice weak words": a lesson built from the learner's weakest words.
//  Reuses the lesson player and result screen. Mistakes here don't cost hearts.
//

import SwiftUI
import SwiftData

struct PracticeCoordinator: View {
    var navRouter: any NavRouterProtocol
    let courseId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(UserSettings.self) private var userSettings

    @State private var items: [VocabItem] = []
    @State private var speechLocale = "en-US"
    @State private var viewModel: LessonSessionViewModel?
    @State private var result: LessonResult?

    var body: some View {
        Group {
            if let result {
                LessonResultView(result: result, onContinue: close)
            } else if let viewModel {
                LessonPlayerView(viewModel: viewModel,
                                 speechLocale: speechLocale,
                                 onClose: close,
                                 onGetPremium: nil)
                    .onChange(of: viewModel.phase) { _, phase in
                        if phase == .finished { finish(viewModel: viewModel) }
                    }
            } else {
                LoadingView(hideText: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .setDefaultBackground()
            }
        }
        .task { loadIfNeeded() }
    }

    private func loadIfNeeded() {
        guard viewModel == nil else { return }
        let id = courseId
        let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.remoteId == id })
        guard let course = try? modelContext.fetch(descriptor).first else {
            Logger.shared.error("Course not found: \(courseId)")
            close()
            return
        }

        let learned = course.allItems.filter(\.isLearned)
        let pickedIds = PracticeService.pickWords(learned.map(\.practiceCandidate))
        let picked = pickedIds.compactMap { id in learned.first { $0.remoteId == id } }
        guard !picked.isEmpty else {
            close()
            return
        }

        let locale = course.speechLocale
        let debug = DebugSettings.shared
        let studyItems = debug.limitLessonWords(picked).map { StudyItem(item: $0, speechLocale: locale) }
        let pool = course.allItems.map { StudyItem(item: $0, speechLocale: locale) }
        var rng = SystemRandomNumberGenerator()
        // All words are known → no intro cards; typing and listening are included.
        let exercises = debug.lessonGenerator().makeLesson(items: studyItems, distractorPool: pool,
                                                       newWordIds: [], using: &rng)
        let vm = LessonSessionViewModel(lessonTitle: "practice_weak_words".localized(), exercises: exercises)
        vm.onMistake = { true }   // practice never costs hearts

        items = picked
        speechLocale = locale
        viewModel = vm
    }

    private func finish(viewModel: LessonSessionViewModel) {
        guard result == nil else { return }
        let outcome = PracticeService.complete(items: items,
                                               mistakes: viewModel.mistakesByItemId,
                                               accuracy: viewModel.accuracy,
                                               dailyGoalXP: userSettings.dailyGoalXP,
                                               in: modelContext)
        FeedbackService.celebrate(sound: userSettings.soundEnabled)
        withAnimation { result = outcome }
    }

    private func close() {
        navRouter.dismiss()
    }
}
