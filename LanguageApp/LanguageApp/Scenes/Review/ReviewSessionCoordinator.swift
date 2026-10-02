//
//  ReviewSessionCoordinator.swift
//  LanguageApp
//

import SwiftUI
import SwiftData

struct ReviewSessionCoordinator: View {
    var navRouter: any NavRouterProtocol
    let courseId: String
    let practiceMode: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumManager.self) private var premium
    @Environment(UserSettings.self) private var userSettings
    @Environment(AppState.self) private var appState
    @State private var viewModel: ReviewSessionViewModel?
    @State private var speechLocale = "en-US"
    @State private var didRecord = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isFinished {
                    ReviewSummaryView(reviewed: viewModel.reviewedCount,
                                      again: viewModel.againCount,
                                      xp: viewModel.xpEarned,
                                      onDone: close)
                        .onAppear { record(viewModel) }
                } else {
                    ReviewSessionView(viewModel: viewModel, speechLocale: speechLocale, onClose: {
                        record(viewModel)
                        close()
                    })
                }
            } else {
                LoadingView(hideText: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .setDefaultBackground()
            }
        }
        .task { load() }
    }

    private func load() {
        guard viewModel == nil else { return }
        let id = courseId
        let courseDescriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.remoteId == id })
        speechLocale = (try? modelContext.fetch(courseDescriptor).first?.speechLocale) ?? "en-US"

        let descriptor = FetchDescriptor<VocabItem>(predicate: #Predicate { $0.courseId == id && $0.srsDue != nil })
        let learned = (try? modelContext.fetch(descriptor)) ?? []
        let limit = premium.isPremium ? nil : ReviewSessionViewModel.freeSessionLimit
        let items = ReviewSessionViewModel.selectItems(from: learned, practice: practiceMode, limit: limit)
        viewModel = ReviewSessionViewModel(items: items)
    }

    private func record(_ viewModel: ReviewSessionViewModel) {
        guard !didRecord, viewModel.reviewedCount > 0 else { return }
        didRecord = true
        ProgressService.record(xp: viewModel.xpEarned, reviews: viewModel.reviewedCount, in: modelContext)
        try? modelContext.save()
        let quests = DailyQuestService.claimCompleted(in: modelContext, dailyGoalXP: userSettings.dailyGoalXP)
        if !quests.isEmpty {
            appState.showToast(item: DailyQuestService.toastItem(for: quests))
        }
    }

    private func close() {
        navRouter.dismiss()
    }
}
