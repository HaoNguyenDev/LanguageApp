//
//  LearningButtonStyles.swift
//  LanguageApp
//
//  Button styles: flat filled action buttons + answer option cards.
//

import SwiftUI

/// Simple flat filled button used for the main actions (Continue, Check, Start…).
struct FilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var color: Color
    var foreground: Color = .white
    var cornerRadius: CGFloat = 14
    var height: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(mainFont.semibold(17))
            .foregroundStyle(isEnabled ? foreground : Color.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isEnabled ? color : Color.gray.opacity(0.35))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Visual state for an answer option.
enum OptionState {
    case normal, selected, correct, wrong, disabled
}

/// Outlined option card for multiple choice / matching exercises.
struct OptionButtonStyle: ButtonStyle {
    @Environment(UserSettings.self) private var userSettings
    var state: OptionState

    func makeBody(configuration: Configuration) -> some View {
        let theme = userSettings.theme
        let (stroke, fill, text): (Color, Color, Color) = {
            switch state {
            case .normal: return (theme.borderColor, theme.bgColor, theme.textColor)
            case .selected: return (theme.primaryColor, theme.primaryColor.opacity(0.12), theme.primaryColor)
            case .correct: return (theme.correctColor, theme.correctBgColor, theme.correctShadowColor)
            case .wrong: return (theme.wrongColor, theme.wrongBgColor, theme.wrongShadowColor)
            case .disabled: return (theme.borderColor, theme.cardBgColor, theme.secondaryTextColor.opacity(0.5))
            }
        }()
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.bgColor)
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(stroke, lineWidth: 2)
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(stroke)
                    .offset(y: pressed ? 0 : 3)
            )
            .offset(y: pressed ? 3 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension Button {
    func filled(_ color: Color, foreground: Color = .white) -> some View {
        self.buttonStyle(FilledButtonStyle(color: color, foreground: foreground))
    }
}
