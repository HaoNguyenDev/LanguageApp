//
//  ExerciseViews.swift
//  LanguageApp
//
//  Intro card, multiple choice (term / meaning / audio) and match pairs.
//

import SwiftUI

// MARK: - Introduce a new word

struct IntroduceWordView: View {
    @Environment(UserSettings.self) private var userSettings
    let item: StudyItem

    var body: some View {
        let theme = userSettings.theme
        VStack(alignment: .leading, spacing: 20) {
            Label("new_word".localized(), systemImage: "sparkles")
                .font(mainFont.bold(15))
                .foregroundStyle(theme.primaryColor)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(theme.primaryColor.opacity(0.12), in: Capsule())

            VStack(spacing: 16) {
                Text(item.term)
                    .setFont(.bold, size: 44, color: theme.textColor, alignment: .center)
                    .minimumScaleFactor(0.5)
                if let reading = item.reading, !reading.isEmpty {
                    Text(reading)
                        .setFont(.medium, size: 20, color: theme.secondaryTextColor, alignment: .center)
                }
                HStack(spacing: 12) {
                    SpeakerButton(text: item.term, locale: item.speechLocale, size: 52)
                    SpeakerButton(text: item.term, locale: item.speechLocale, size: 40, slow: true)
                }
                Divider().padding(.vertical, 4)
                Text(item.meaning)
                    .setFont(.semibold, size: 24, color: theme.primaryColor, alignment: .center)
                if let example = item.example {
                    VStack(spacing: 4) {
                        Text(example)
                            .setFont(.medium, size: 16, color: theme.textColor, alignment: .center)
                        if let exampleMeaning = item.exampleMeaning {
                            Text(exampleMeaning)
                                .setFont(.regular, size: 14, color: theme.secondaryTextColor, alignment: .center)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

// MARK: - Multiple choice

struct ChoiceExerciseView: View {
    enum Prompt {
        case term(StudyItem)
        case meaning(String)
        case audio(StudyItem)
        /// Example sentence with a blank where the word goes, plus its meaning.
        case sentence(before: String, after: String, meaning: String?)
    }

    @Environment(UserSettings.self) private var userSettings
    let instruction: String
    let prompt: Prompt
    let options: [ChoiceOption]
    @Bindable var viewModel: LessonSessionViewModel

    var body: some View {
        let theme = userSettings.theme
        VStack(alignment: .leading, spacing: 24) {
            Text(instruction)
                .setFont(.bold, size: 22, color: theme.textColor)

            promptView
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                ForEach(options) { option in
                    Button {
                        FeedbackService.tap()
                        viewModel.select(option.id)
                    } label: {
                        VStack(spacing: 2) {
                            Text(option.text)
                                .font(mainFont.bold(18))
                                .multilineTextAlignment(.center)
                            if let subtitle = option.subtitle, !subtitle.isEmpty, showsSubtitles {
                                Text(subtitle)
                                    .font(mainFont.regular(13))
                                    .opacity(0.75)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(OptionButtonStyle(state: state(for: option)))
                    .disabled(viewModel.phase != .answering)
                }
            }
        }
    }

    /// Hide readings on the options for the listening exercise until answered (no hints).
    private var showsSubtitles: Bool {
        if case .audio = prompt { return viewModel.phase != .answering }
        return true
    }

    @ViewBuilder
    private var promptView: some View {
        let theme = userSettings.theme
        switch prompt {
        case .term(let item):
            HStack(spacing: 16) {
                SpeakerButton(text: item.term, locale: item.speechLocale)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.term)
                        .setFont(.bold, size: 32, color: theme.textColor)
                    if let reading = item.reading, !reading.isEmpty {
                        Text(reading)
                            .setFont(.regular, size: 16, color: theme.secondaryTextColor)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        case .meaning(let meaning):
            Text("“\(meaning)”")
                .setFont(.bold, size: 28, color: theme.textColor, alignment: .center)
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        case .audio(let item):
            HStack(spacing: 20) {
                SpeakerButton(text: item.term, locale: item.speechLocale, size: 96)
                SpeakerButton(text: item.term, locale: item.speechLocale, size: 60, slow: true)
            }
            .padding(.vertical, 12)
        case .sentence(let before, let after, let meaning):
            VStack(alignment: .leading, spacing: 10) {
                Text(blankSentence(before: before, after: after))
                    .font(mainFont.bold(24))
                    .foregroundStyle(theme.textColor)
                if let meaning, !meaning.isEmpty {
                    Text(meaning)
                        .setFont(.regular, size: 15, color: theme.secondaryTextColor)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    /// "I like to ＿＿＿ rice." – the blank shows the chosen option once answered.
    private func blankSentence(before: String, after: String) -> AttributedString {
        let theme = userSettings.theme
        let answered = viewModel.phase != .answering
        let chosen = answered ? options.first { $0.id == viewModel.selectedOptionId }?.text : nil
        var blank = AttributedString(chosen ?? "＿＿＿")
        blank.foregroundColor = answered
            ? (viewModel.selectedOptionId == viewModel.current?.correctOptionId ? theme.correctColor : theme.wrongColor)
            : theme.primaryColor
        return AttributedString(before) + blank + AttributedString(after)
    }

    private func state(for option: ChoiceOption) -> OptionState {
        switch viewModel.phase {
        case .answering:
            return viewModel.selectedOptionId == option.id ? .selected : .normal
        case .feedback, .outOfHearts, .finished:
            if option.id == viewModel.current?.correctOptionId { return .correct }
            if option.id == viewModel.selectedOptionId { return .wrong }
            return .disabled
        }
    }
}

// MARK: - Typing

struct TypingExerciseView: View {
    enum Prompt {
        case meaning(StudyItem)
        case audio(StudyItem)
    }

    @Environment(UserSettings.self) private var userSettings
    let instruction: String
    let prompt: Prompt
    @Bindable var viewModel: LessonSessionViewModel
    var onSubmit: VoidResult?

    @FocusState private var isFocused: Bool

    private var item: StudyItem {
        switch prompt {
        case .meaning(let item), .audio(let item): return item
        }
    }

    var body: some View {
        let theme = userSettings.theme
        VStack(alignment: .leading, spacing: 24) {
            Text(instruction)
                .setFont(.bold, size: 22, color: theme.textColor)

            promptView
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                TextField("typing_placeholder".localized(), text: $viewModel.typedAnswer)
                    .font(mainFont.semibold(20))
                    .foregroundStyle(theme.textColor)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isFocused)
                    .disabled(viewModel.phase != .answering)
                    .padding(16)
                    .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(borderColor, lineWidth: 2)
                    }
                    .onSubmit { onSubmit?() }

                if showsRomanizedHint {
                    Label("typing_hint_romanized".localized(), systemImage: "lightbulb")
                        .font(mainFont.regular(13))
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
        }
        .task {
            // Let the slide-in transition finish before the keyboard appears.
            try? await Task.sleep(for: .milliseconds(400))
            isFocused = true
        }
        .onChange(of: viewModel.phase) { _, phase in
            if phase != .answering { isFocused = false }
        }
    }

    @ViewBuilder
    private var promptView: some View {
        let theme = userSettings.theme
        switch prompt {
        case .meaning(let item):
            Text("“\(item.meaning)”")
                .setFont(.bold, size: 28, color: theme.textColor, alignment: .center)
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        case .audio(let item):
            HStack(spacing: 20) {
                SpeakerButton(text: item.term, locale: item.speechLocale, size: 96)
                SpeakerButton(text: item.term, locale: item.speechLocale, size: 60, slow: true)
            }
            .padding(.vertical, 12)
        }
    }

    private var borderColor: Color {
        let theme = userSettings.theme
        switch viewModel.phase {
        case .feedback(let isCorrect):
            return isCorrect ? theme.correctColor : theme.wrongColor
        default:
            return isFocused ? theme.primaryColor : theme.secondaryTextColor.opacity(0.25)
        }
    }

    /// Chinese, Japanese and Korean words can also be typed in Latin letters (Pinyin, Romaji, Romanization).
    private var showsRomanizedHint: Bool {
        guard let reading = item.reading, !reading.isEmpty else { return false }
        let language = item.speechLocale.prefix(2)
        return ["zh", "ja", "ko"].contains(String(language))
    }
}

// MARK: - Match pairs

struct MatchPairsView: View {
    private struct Tile: Identifiable, Hashable {
        let id: String      // "\(side)-\(itemId)"
        let itemId: String
        let text: String
        let isTerm: Bool
    }

    @Environment(UserSettings.self) private var userSettings
    @Environment(SpeechService.self) private var speech
    let items: [StudyItem]
    var onComplete: (Int) -> Void

    @State private var leftTiles: [Tile] = []
    @State private var rightTiles: [Tile] = []
    @State private var selectedLeft: Tile?
    @State private var selectedRight: Tile?
    @State private var matched = Set<String>()
    @State private var wrongPair: Set<String> = []
    @State private var mistakes = 0
    @State private var didComplete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("exercise_match_pairs".localized())
                .setFont(.bold, size: 22, color: userSettings.theme.textColor)

            HStack(alignment: .top, spacing: 12) {
                column(leftTiles)
                column(rightTiles)
            }
        }
        .onAppear(perform: setup)
    }

    private func column(_ tiles: [Tile]) -> some View {
        VStack(spacing: 12) {
            ForEach(tiles) { tile in
                Button {
                    tap(tile)
                } label: {
                    Text(tile.text)
                        .font(mainFont.bold(tile.isTerm ? 20 : 16))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                        .padding(.vertical, 6)
                }
                .buttonStyle(OptionButtonStyle(state: state(for: tile)))
                .disabled(matched.contains(tile.itemId))
                .opacity(matched.contains(tile.itemId) ? 0.45 : 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func setup() {
        guard leftTiles.isEmpty else { return }
        leftTiles = items.map { Tile(id: "t-\($0.id)", itemId: $0.id, text: $0.term, isTerm: true) }.shuffled()
        rightTiles = items.map { Tile(id: "m-\($0.id)", itemId: $0.id, text: $0.meaning, isTerm: false) }.shuffled()
    }

    private func state(for tile: Tile) -> OptionState {
        if matched.contains(tile.itemId) { return .correct }
        if wrongPair.contains(tile.id) { return .wrong }
        if selectedLeft == tile || selectedRight == tile { return .selected }
        return .normal
    }

    private func tap(_ tile: Tile) {
        FeedbackService.tap()
        if tile.isTerm {
            selectedLeft = tile
            if let item = items.first(where: { $0.id == tile.itemId }) {
                speech.speak(item.term, locale: item.speechLocale)
            }
        } else {
            selectedRight = tile
        }
        guard let left = selectedLeft, let right = selectedRight else { return }

        if left.itemId == right.itemId {
            withAnimation(.easeOut(duration: 0.2)) { _ = matched.insert(left.itemId) }
            selectedLeft = nil
            selectedRight = nil
            if matched.count == items.count, !didComplete {
                didComplete = true
                onComplete(mistakes)
            }
        } else {
            mistakes += 1
            FeedbackService.wrong(sound: false)
            wrongPair = [left.id, right.id]
            selectedLeft = nil
            selectedRight = nil
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                wrongPair = []
            }
        }
    }
}
