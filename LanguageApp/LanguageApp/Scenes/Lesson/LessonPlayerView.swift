//
//  LessonPlayerView.swift
//  LanguageApp
//

import SwiftUI

struct LessonPlayerView: View {
    @Bindable var viewModel: LessonSessionViewModel
    let speechLocale: String
    var onClose: VoidResult?
    var onGetPremium: VoidResult?

    @Environment(UserSettings.self) private var userSettings
    @Environment(GamificationManager.self) private var gamification
    @Environment(PremiumManager.self) private var premium
    @Environment(SpeechService.self) private var speech

    @State private var showQuitConfirm = false

    private var theme: Theme { userSettings.theme }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 8)

            ScrollView {
                exerciseContent
                    .id(viewModel.currentIndex)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            bottomArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentIndex)
        .overlay {
            if viewModel.phase == .outOfHearts {
                OutOfHeartsView(onGetPremium: onGetPremium, onQuit: onClose)
                    .transition(.opacity)
            }
        }
        .confirmationDialog("quit_lesson_title".localized(), isPresented: $showQuitConfirm, titleVisibility: .visible) {
            Button("quit_lesson_confirm".localized(), role: .destructive) { onClose?() }
            Button("keep_learning".localized(), role: .cancel) {}
        } message: {
            Text("quit_lesson_message".localized())
        }
        .onChange(of: viewModel.currentIndex, initial: true) { _, _ in autoPlayIfNeeded() }
        .onDisappear { speech.stop() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                showQuitConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.secondaryTextColor)
            }
            LessonProgressBar(progress: viewModel.progress)
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(theme.heartColor)
                Text(premium.isPremium ? "∞" : "\(gamification.hearts)")
                    .setFont(.bold, size: 17, color: theme.heartColor)
                    .contentTransition(.numericText())
            }
            .font(.system(size: 20))
            .animation(.snappy, value: gamification.hearts)
        }
    }

    // MARK: - Exercise

    @ViewBuilder
    private var exerciseContent: some View {
        switch viewModel.current {
        case .introduce(let item):
            IntroduceWordView(item: item)
        case .chooseMeaning(let item, let options):
            ChoiceExerciseView(instruction: "exercise_choose_meaning".localized(),
                               prompt: .term(item),
                               options: options,
                               viewModel: viewModel)
        case .chooseTerm(let item, let options):
            ChoiceExerciseView(instruction: "exercise_choose_term".localized(),
                               prompt: .meaning(item.meaning),
                               options: options,
                               viewModel: viewModel)
        case .listen(let item, let options):
            ChoiceExerciseView(instruction: "exercise_listen".localized(),
                               prompt: .audio(item),
                               options: options,
                               viewModel: viewModel)
        case .typeTerm(let item):
            TypingExerciseView(instruction: "exercise_type_term".localized(),
                               prompt: .meaning(item),
                               viewModel: viewModel,
                               onSubmit: submitTyped)
        case .typeListening(let item):
            TypingExerciseView(instruction: "exercise_type_listening".localized(),
                               prompt: .audio(item),
                               viewModel: viewModel,
                               onSubmit: submitTyped)
        case .matchPairs(let items):
            MatchPairsView(items: items) { mistakes in
                viewModel.completeMatch(mistakes: mistakes)
                if mistakes == 0 {
                    FeedbackService.correct(sound: userSettings.soundEnabled)
                }
            }
        case .none:
            EmptyView()
        }
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottomArea: some View {
        switch viewModel.phase {
        case .feedback(let isCorrect):
            FeedbackBanner(isCorrect: isCorrect,
                           isAlmost: viewModel.lastAnswerWasAlmost,
                           correctAnswer: correctAnswerText,
                           onContinue: { viewModel.next() })
                .transition(.move(edge: .bottom))
        case .answering:
            Group {
                if case .introduce = viewModel.current {
                    Button("continue".localized()) { viewModel.next() }
                        .filled(theme.primaryColor)
                } else if case .matchPairs = viewModel.current {
                    Color.clear.frame(height: 52)
                } else {
                    Button("check".localized()) { checkAnswer() }
                        .filled(theme.correctColor)
                        .disabled(!viewModel.canCheck)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        case .outOfHearts, .finished:
            Color.clear.frame(height: 84)
        }
    }

    private var correctAnswerText: String? {
        switch viewModel.current {
        case .chooseMeaning(let item, _):
            return item.meaning
        case .chooseTerm(let item, _), .listen(let item, _), .typeTerm(let item), .typeListening(let item):
            if let reading = item.reading, !reading.isEmpty { return "\(item.term) · \(reading)" }
            return item.term
        default:
            return nil
        }
    }

    /// Return key on the keyboard = Check.
    private func submitTyped() {
        if viewModel.canCheck { checkAnswer() }
    }

    private func checkAnswer() {
        let isCorrect = viewModel.check()
        if isCorrect {
            FeedbackService.correct(sound: userSettings.soundEnabled)
            if userSettings.autoPlayAudio, let item = viewModel.current?.studyItem {
                speech.speak(item.term, locale: speechLocale)
            }
        } else {
            FeedbackService.wrong(sound: userSettings.soundEnabled)
        }
    }

    private func autoPlayIfNeeded() {
        guard userSettings.autoPlayAudio || isListenExercise else { return }
        switch viewModel.current {
        case .introduce(let item), .chooseMeaning(let item, _), .listen(let item, _), .typeListening(let item):
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                speech.speak(item.term, locale: speechLocale)
            }
        default:
            break
        }
    }

    private var isListenExercise: Bool {
        switch viewModel.current {
        case .listen, .typeListening: return true
        default: return false
        }
    }
}

// MARK: - Feedback banner

private struct FeedbackBanner: View {
    @Environment(UserSettings.self) private var userSettings
    let isCorrect: Bool
    /// Accepted with a spelling slip → show the correct spelling.
    var isAlmost = false
    let correctAnswer: String?
    var onContinue: VoidResult?

    var body: some View {
        let theme = userSettings.theme
        let color = isCorrect ? theme.correctShadowColor : theme.wrongShadowColor
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 28))
                Text((isCorrect ? "feedback_correct" : "feedback_wrong").localized())
                    .setFont(.bold, size: 22, color: color)
            }
            .foregroundStyle(color)

            if !isCorrect || isAlmost, let correctAnswer {
                VStack(alignment: .leading, spacing: 2) {
                    Text((isAlmost ? "typo_note" : "correct_answer").localized())
                        .setFont(.bold, size: 15, color: color)
                    Text(correctAnswer)
                        .setFont(.regular, size: 17, color: color)
                }
            }

            Button("continue".localized()) { onContinue?() }
                .filled(isCorrect ? theme.correctColor : theme.wrongColor)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isCorrect ? theme.correctBgColor : theme.wrongBgColor).ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Out of hearts

private struct OutOfHeartsView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(GamificationManager.self) private var gamification
    var onGetPremium: VoidResult?
    var onQuit: VoidResult?

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 72))
                .foregroundStyle(theme.heartColor)
            Text("out_of_hearts_title".localized())
                .setFont(.bold, size: 26, color: theme.textColor, alignment: .center)
            Text("out_of_hearts_message".localized())
                .setFont(.regular, size: 16, color: theme.secondaryTextColor, alignment: .center)
            if let next = gamification.nextHeartDate() {
                HStack(spacing: 4) {
                    Text("next_heart_in".localized())
                    Text(next, style: .timer)
                }
                .font(mainFont.semibold(15))
                .foregroundStyle(theme.secondaryTextColor)
            }
            Spacer()
            Button("get_plus_unlimited_hearts".localized()) { onGetPremium?() }
                .filled(theme.primaryColor)
            Button("quit_lesson_confirm".localized()) { onQuit?() }
                .buttonStyle(TextButtonStyle(color: theme.secondaryTextColor))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgColor.ignoresSafeArea())
    }
}
