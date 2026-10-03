//
//  ReviewSessionView.swift
//  LanguageApp
//

import SwiftUI
import Lottie

struct ReviewSessionView: View {
    @Bindable var viewModel: ReviewSessionViewModel
    let speechLocale: String
    var onClose: VoidResult?

    @Environment(UserSettings.self) private var userSettings
    @Environment(SpeechService.self) private var speech

    @State private var showGuide = false

    private var theme: Theme { userSettings.theme }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                Button { onClose?() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.secondaryTextColor)
                }
                LessonProgressBar(progress: viewModel.progress, color: theme.primaryColor)
                Text("\(viewModel.reviewedCount)")
                    .setFont(.bold, size: 16, color: theme.secondaryTextColor)
                    .monospacedDigit()
                ReviewGuideButton()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            if let item = viewModel.current {
                FlashcardView(item: item, speechLocale: speechLocale, isFlipped: viewModel.isFlipped)
                    .id("\(item.remoteId)-\(viewModel.index)")
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                    .onTapGesture { flip() }
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity)
            }

            bottomArea
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .animation(.easeInOut(duration: 0.25), value: viewModel.index)
        .onAppear {
            // First review session ever: explain how it works before the first card.
            if !userSettings.hasSeenReviewGuide { showGuide = true }
        }
        .sheet(isPresented: $showGuide, onDismiss: { userSettings.hasSeenReviewGuide = true }) {
            ReviewGuideView(onClose: { showGuide = false })
        }
        .onChange(of: viewModel.index, initial: true) { _, _ in
            if userSettings.autoPlayAudio, let item = viewModel.current {
                speech.speak(item.term, locale: speechLocale)
            }
        }
    }

    @ViewBuilder
    private var bottomArea: some View {
        if viewModel.isFlipped {
            let labels = viewModel.previewLabels()
            HStack(spacing: 8) {
                ForEach(ReviewGrade.allCases) { grade in
                    Button {
                        FeedbackService.tap()
                        withAnimation { viewModel.grade(grade) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(grade.titleKey.localized())
                                .font(mainFont.bold(14))
                            Text(labels[grade] ?? "")
                                .font(mainFont.regular(12))
                                .opacity(0.85)
                        }
                    }
                    .buttonStyle(FilledButtonStyle(color: grade.color(theme), height: 56))
                }
            }
        } else {
            Button("show_answer".localized()) { flip() }
                .filled(theme.primaryColor)
        }
    }

    private func flip() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { viewModel.flip() }
    }

}

// MARK: - Flashcard

struct FlashcardView: View {
    @Environment(UserSettings.self) private var userSettings
    let item: VocabItem
    let speechLocale: String
    let isFlipped: Bool

    var body: some View {
        ZStack {
            face(isFront: true)
                .opacity(isFlipped ? 0 : 1)
            face(isFront: false)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }

    private func face(isFront: Bool) -> some View {
        let theme = userSettings.theme
        return VStack(spacing: 16) {
            Spacer()
            Text(item.term)
                .setFont(.bold, size: 46, color: theme.textColor, alignment: .center)
                .minimumScaleFactor(0.4)
            SpeakerButton(text: item.term, locale: speechLocale, size: 48)
            if isFront {
                Spacer()
                Text("tap_to_flip".localized())
                    .setFont(.regular, size: 14, color: theme.secondaryTextColor)
            } else {
                if let reading = item.reading, !reading.isEmpty {
                    Text(reading)
                        .setFont(.medium, size: 20, color: theme.secondaryTextColor, alignment: .center)
                }
                Divider().padding(.horizontal, 24)
                Text(item.meaning.text)
                    .setFont(.bold, size: 26, color: theme.primaryColor, alignment: .center)
                if let example = item.example {
                    ExampleSentenceView(example: example, meaning: item.exampleMeaning?.text, locale: speechLocale)
                }
                Spacer()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: 460)
        .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(theme.borderColor, lineWidth: 2))
    }
}

// MARK: - Summary

struct ReviewSummaryView: View {
    @Environment(UserSettings.self) private var userSettings
    let reviewed: Int
    let again: Int
    let xp: Int
    var onDone: VoidResult?

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 20) {
            Spacer()
            if reviewed == 0 {
                LottieHelperView(fileName: "NoHistory")
                    .frame(width: 200, height: 200)
                Text("no_cards_due".localized())
                    .setFont(.bold, size: 24, color: theme.textColor, alignment: .center)
            } else {
                LottieHelperView(fileName: "SuccessCircle", playLoopMode: .playOnce)
                    .frame(width: 180, height: 180)
                Text("review_complete".localized())
                    .setFont(.bold, size: 28, color: theme.textColor, alignment: .center)
                HStack(spacing: 24) {
                    summaryStat(value: "\(reviewed)", label: "cards_reviewed".localized(), color: theme.primaryColor)
                    summaryStat(value: "\(reviewed - again)", label: "remembered".localized(), color: theme.correctColor)
                    summaryStat(value: "+\(xp)", label: "XP", color: theme.xpColor)
                }
            }
            Spacer()
            Button("done".localized()) { onDone?() }
                .filled(theme.primaryColor)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
    }

    private func summaryStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).setFont(.bold, size: 28, color: color)
            Text(label).setFont(.medium, size: 13, color: userSettings.theme.secondaryTextColor)
        }
    }
}
