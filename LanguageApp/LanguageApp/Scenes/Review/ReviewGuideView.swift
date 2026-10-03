//
//  ReviewGuideView.swift
//  LanguageApp
//
//  "How reviews work": spaced repetition and the 4 grade buttons, explained in plain words.
//  Shown automatically before the first review session and from the ⓘ buttons
//  (Review tab title, review session top bar).
//

import SwiftUI

extension ReviewGrade {
    func color(_ theme: Theme) -> Color {
        switch self {
        case .again: return theme.wrongColor
        case .hard: return theme.streakColor
        case .good: return theme.correctColor
        case .easy: return Color(hex: "#0EA5E9")
        }
    }

    /// When to press the button (guide).
    var descriptionKey: String { titleKey + "_desc" }
}

struct ReviewGuideView: View {
    @Environment(UserSettings.self) private var userSettings
    var onClose: VoidResult?

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(theme.primaryColor)
                        Text("review_guide_title".localized())
                            .setFont(.bold, size: 26, color: theme.textColor, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    section(icon: "brain.head.profile", title: "review_guide_why_title".localized()) {
                        Text("review_guide_why_body".localized())
                            .setFont(.regular, size: 15, color: theme.secondaryTextColor)
                    }

                    section(icon: "list.number", title: "review_guide_steps_title".localized()) {
                        VStack(alignment: .leading, spacing: 10) {
                            step(1, "review_guide_step_1".localized())
                            step(2, "review_guide_step_2".localized())
                            step(3, "review_guide_step_3".localized())
                        }
                    }

                    section(icon: "hand.tap.fill", title: "review_guide_buttons_title".localized()) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(ReviewGrade.allCases) { grade in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(grade.titleKey.localized())
                                        .font(mainFont.bold(14))
                                        .foregroundStyle(.white)
                                        .frame(width: 72, height: 34)
                                        .background(grade.color(theme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text(grade.descriptionKey.localized())
                                        .setFont(.regular, size: 14, color: theme.textColor)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Label("review_guide_buttons_hint".localized(), systemImage: "clock")
                                .font(mainFont.regular(13))
                                .foregroundStyle(theme.secondaryTextColor)
                        }
                    }

                    Label("review_guide_tip".localized(), systemImage: "lightbulb.fill")
                        .font(mainFont.semibold(14))
                        .foregroundStyle(theme.textColor)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.xpColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(24)
            }

            Button("review_guide_done".localized()) { onClose?() }
                .filled(theme.primaryColor)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
    }

    private func section<Content: View>(icon: String, title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        let theme = userSettings.theme
        return VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(mainFont.bold(17))
                .foregroundStyle(theme.textColor)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        let theme = userSettings.theme
        return HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(mainFont.bold(13))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(theme.primaryColor, in: Circle())
            Text(text)
                .setFont(.regular, size: 14, color: theme.textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Small ⓘ button that opens the guide.
struct ReviewGuideButton: View {
    @Environment(UserSettings.self) private var userSettings
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(userSettings.theme.secondaryTextColor)
        }
        .accessibilityLabel("review_guide_title".localized())
        .sheet(isPresented: $isPresented) {
            ReviewGuideView(onClose: { isPresented = false })
        }
    }
}

#Preview {
    ReviewGuideView()
        .environment(UserSettings())
}
