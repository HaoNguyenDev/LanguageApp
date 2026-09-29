//
//  OnboardingView.swift
//  LanguageApp
//
//  App (UI) language → language to learn → daily goal → reminder.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case appLanguage, language, goal, reminder
    }

    @Environment(UserSettings.self) private var userSettings
    @Query(sort: \Course.order) private var courses: [Course]

    var onFinish: ((_ courseId: String, _ goal: DailyGoal, _ reminder: Bool) -> Void)?

    @State private var step: Step = .appLanguage
    @State private var selectedCourseId: String?
    @State private var selectedGoal: DailyGoal = .regular

    /// Courses offered for the chosen UI language (don't offer to "learn" the app language).
    private var availableCourses: [Course] {
        courses.filter { !$0.isSameLanguage(asUILanguage: userSettings.languageCode) }
    }

    private var theme: Theme { userSettings.theme }

    var body: some View {
        VStack(spacing: 0) {
            if step != .appLanguage {
                topBar
            }
            Group {
                switch step {
                case .appLanguage: ScrollView(showsIndicators: false) { appLanguageStep }
                case .language: languageStep
                case .goal: goalStep
                case .reminder: reminderStep
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .frame(maxHeight: .infinity, alignment: .top)

            bottomButton
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.secondaryTextColor)
            }
            LessonProgressBar(progress: Double(step.rawValue) / Double(Step.allCases.count - 1),
                              color: theme.primaryColor)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Steps

    private var appLanguageStep: some View {
        VStack(spacing: 16) {
            LottieHelperView(fileName: "WaveHand")
                .frame(width: 140, height: 140)
                .padding(.top, 16)
            Text("onboarding_welcome_title".localized())
                .setFont(.bold, size: 28, color: theme.textColor, alignment: .center)
            Text("onboarding_welcome_message".localized())
                .setFont(.regular, size: 15, color: theme.secondaryTextColor, alignment: .center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                Text("onboarding_choose_app_language".localized())
                    .setFont(.bold, size: 20, color: theme.textColor)
                ForEach(LanguageCode.allCases, id: \.self) { code in
                    let isSelected = userSettings.languageCode == code.rawValue
                    Button {
                        FeedbackService.tap()
                        selectUILanguage(code)
                    } label: {
                        HStack(spacing: 14) {
                            LanguageBadge(uiLanguage: code, size: 40)
                            Text(code.title)
                                .setFont(.bold, size: 18, color: theme.textColor)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(theme.primaryColor)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(OptionButtonStyle(state: isSelected ? .selected : .normal))
                }
                Text("onboarding_app_language_hint".localized())
                    .setFont(.regular, size: 13, color: theme.secondaryTextColor)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("onboarding_choose_language".localized())
                    .setFont(.bold, size: 26, color: theme.textColor)
                Text("onboarding_choose_language_hint".localized())
                    .setFont(.regular, size: 15, color: theme.secondaryTextColor)
            }
            .padding(.horizontal, 24)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(availableCourses) { course in
                        Button {
                            FeedbackService.tap()
                            selectedCourseId = course.remoteId
                        } label: {
                            HStack(spacing: 16) {
                                LanguageBadge(courseId: course.remoteId, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name.text)
                                        .setFont(.bold, size: 18, color: theme.textColor)
                                    Text(course.nativeName)
                                        .setFont(.regular, size: 14, color: theme.secondaryTextColor)
                                }
                                Spacer()
                                if selectedCourseId == course.remoteId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(theme.primaryColor)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(OptionButtonStyle(state: selectedCourseId == course.remoteId ? .selected : .normal))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("onboarding_choose_goal".localized())
                .setFont(.bold, size: 26, color: theme.textColor)
            Text("onboarding_goal_hint".localized())
                .setFont(.regular, size: 15, color: theme.secondaryTextColor)
            ForEach(DailyGoal.allCases) { goal in
                Button {
                    FeedbackService.tap()
                    selectedGoal = goal
                } label: {
                    HStack {
                        Text(goal.minutesKey.localized())
                            .setFont(.bold, size: 17, color: theme.textColor)
                        Spacer()
                        Text(goal.titleKey.localized())
                            .setFont(.regular, size: 15, color: theme.secondaryTextColor)
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(OptionButtonStyle(state: selectedGoal == goal ? .selected : .normal))
            }
        }
        .padding(.horizontal, 24)
    }

    private var reminderStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundStyle(theme.streakColor)
                .symbolEffect(.pulse)
            Text("onboarding_reminder_title".localized())
                .setFont(.bold, size: 26, color: theme.textColor, alignment: .center)
            Text("onboarding_reminder_message".localized())
                .setFont(.regular, size: 16, color: theme.secondaryTextColor, alignment: .center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottomButton: some View {
        switch step {
        case .appLanguage:
            Button("continue".localized()) { step = .language }
                .filled(theme.primaryColor)
        case .language:
            Button("continue".localized()) { step = .goal }
                .filled(theme.primaryColor)
                .disabled(selectedCourseId == nil)
        case .goal:
            Button("continue".localized()) { step = .reminder }
                .filled(theme.primaryColor)
        case .reminder:
            VStack(spacing: 12) {
                Button("enable_reminder".localized()) {
                    Task {
                        let granted = await NotificationManager.requestAuthorization()
                        finish(reminder: granted)
                    }
                }
                .filled(theme.primaryColor)
                Button("not_now".localized()) { finish(reminder: false) }
                    .buttonStyle(TextButtonStyle(color: theme.secondaryTextColor))
            }
        }
    }

    /// Switches the UI language immediately so the rest of onboarding is shown in it.
    private func selectUILanguage(_ code: LanguageCode) {
        LanguageManager.shared.setLanguage(language: code.getLanguage())
        userSettings.languageCode = code.rawValue
        if let selected = selectedCourseId,
           courses.first(where: { $0.remoteId == selected })?.isSameLanguage(asUILanguage: code.rawValue) == true {
            selectedCourseId = nil
        }
    }

    private func finish(reminder: Bool) {
        guard let courseId = selectedCourseId ?? availableCourses.first?.remoteId else { return }
        onFinish?(courseId, selectedGoal, reminder)
    }
}

#Preview {
    OnboardingView()
        .environment(UserSettings())
        .modelContainer(PersistenceController.preview)
}
