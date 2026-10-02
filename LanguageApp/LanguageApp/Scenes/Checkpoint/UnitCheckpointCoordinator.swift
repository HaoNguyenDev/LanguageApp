//
//  UnitCheckpointCoordinator.swift
//  LanguageApp
//
//  Loads a unit checkpoint (test on the unit's words), plays it with the lesson player and
//  shows the result (passed → next unit unlocked; failed → try again from the path).
//

import SwiftUI
import SwiftData

struct UnitCheckpointCoordinator: View {
    var navRouter: any NavRouterProtocol
    let unitId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(UserSettings.self) private var userSettings
    @Environment(GamificationManager.self) private var gamification
    @Environment(PremiumManager.self) private var premium

    @State private var unit: CourseUnit?
    @State private var items: [VocabItem] = []
    @State private var speechLocale = "en-US"
    @State private var viewModel: LessonSessionViewModel?
    @State private var result: LessonResult?
    @State private var showPaywall = false

    var body: some View {
        Group {
            if let result {
                LessonResultView(result: result, onContinue: close)
            } else if let viewModel, let unit {
                LessonPlayerView(viewModel: viewModel,
                                 speechLocale: speechLocale,
                                 onClose: close,
                                 onGetPremium: { showPaywall = true })
                    .onChange(of: viewModel.phase) { _, phase in
                        if phase == .finished { finish(unit: unit, viewModel: viewModel) }
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
        guard unit == nil else { return }
        let id = unitId
        let descriptor = FetchDescriptor<CourseUnit>(predicate: #Predicate { $0.remoteId == id })
        guard let found = try? modelContext.fetch(descriptor).first, let course = found.course else {
            Logger.shared.error("Unit not found: \(unitId)")
            close()
            return
        }

        var rng = SystemRandomNumberGenerator()
        let unitWords = found.allItems
        let pickedIds = UnitCheckpointService.pickWords(unitWords.map(\.practiceCandidate), using: &rng)
        let byId = Dictionary(unitWords.map { ($0.remoteId, $0) }, uniquingKeysWith: { first, _ in first })
        let picked = DebugSettings.shared.limitLessonWords(pickedIds.compactMap { byId[$0] })

        let locale = course.speechLocale
        let studyItems = picked.map { StudyItem(item: $0, speechLocale: locale) }
        let pool = course.allItems.map { StudyItem(item: $0, speechLocale: locale) }
        let intro = "checkpoint_intro".localizedFormat(Int((UnitCheckpointService.passAccuracy * 100).rounded()))
        let exercises = DebugSettings.shared.lessonGenerator().makeCheckpoint(items: studyItems,
                                                                               distractorPool: pool,
                                                                               intro: intro,
                                                                               using: &rng)
        let title = "checkpoint_title".localizedFormat((course.sortedUnits.firstIndex { $0.remoteId == found.remoteId } ?? 0) + 1)
        let vm = LessonSessionViewModel(lessonTitle: title, exercises: exercises)
        let hearts = gamification
        let store = premium
        vm.onMistake = {
            hearts.loseHeart(isPremium: store.isPremium)
            return hearts.hasHearts(isPremium: store.isPremium)
        }
        unit = found
        items = picked
        speechLocale = locale
        viewModel = vm
    }

    private func finish(unit: CourseUnit, viewModel: LessonSessionViewModel) {
        guard result == nil else { return }
        let outcome = UnitCheckpointService.complete(unit: unit,
                                                     items: items,
                                                     accuracy: viewModel.accuracy,
                                                     dailyGoalXP: userSettings.dailyGoalXP,
                                                     mistakes: viewModel.mistakesByItemId,
                                                     in: modelContext)
        if outcome.checkpoint?.passed == true {
            FeedbackService.celebrate(sound: userSettings.soundEnabled)
        }
        withAnimation { result = outcome }
    }

    private func close() {
        navRouter.dismiss()
    }
}
