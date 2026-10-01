//
//  SentenceBuilderView.swift
//  LanguageApp
//
//  Sentence builder: the example's meaning is shown; the learner taps the chunks of the example
//  (plus a few distractors) in the right order.
//

import SwiftUI

struct SentenceBuilderView: View {
    @Environment(UserSettings.self) private var userSettings
    let item: StudyItem
    let tiles: [SentenceTile]
    @Bindable var viewModel: LessonSessionViewModel

    private var theme: Theme { userSettings.theme }

    private var arrangedTiles: [SentenceTile] {
        viewModel.arrangedTileIds.compactMap { id in tiles.first { $0.id == id } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("exercise_build_sentence".localized())
                .setFont(.bold, size: 22, color: theme.textColor)

            HStack(alignment: .center, spacing: 14) {
                SpeakerButton(text: item.example ?? item.term, locale: item.speechLocale, size: 44)
                Text(item.exampleMeaning ?? "")
                    .setFont(.semibold, size: 19, color: theme.textColor)
                Spacer(minLength: 0)
            }
            .padding(18)
            .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Answer line – tap a chunk to send it back.
            FlowLayout(spacing: 8, lineSpacing: 10) {
                ForEach(arrangedTiles) { tile in
                    tileButton(tile)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(12)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(answerBorderColor, style: StrokeStyle(lineWidth: 2, dash: viewModel.phase == .answering ? [6, 4] : []))
            }
            .animation(.snappy(duration: 0.2), value: viewModel.arrangedTileIds)

            // Word bank – used chunks leave an empty slot so the bank doesn't jump around.
            FlowLayout(spacing: 8, lineSpacing: 10) {
                ForEach(tiles) { tile in
                    if viewModel.arrangedTileIds.contains(tile.id) {
                        tileLabel(tile.text)
                            .hidden()
                            .background(theme.borderColor.opacity(0.6),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        tileButton(tile)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func tileLabel(_ text: String) -> some View {
        Text(text)
            .font(mainFont.semibold(18))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
    }

    private func tileButton(_ tile: SentenceTile) -> some View {
        Button {
            FeedbackService.tap()
            viewModel.toggleTile(tile.id)
        } label: {
            tileLabel(tile.text)
                .foregroundStyle(theme.textColor)
                .background(theme.bgColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.borderColor, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.phase != .answering)
    }

    private var answerBorderColor: Color {
        switch viewModel.phase {
        case .feedback(let isCorrect):
            return isCorrect ? theme.correctColor : theme.wrongColor
        default:
            return theme.borderColor
        }
    }
}
