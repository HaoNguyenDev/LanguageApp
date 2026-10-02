//
//  LearnView.swift
//  LanguageApp
//
//  Duolingo-style learning path: units → zig-zag lesson nodes.
//

import SwiftUI
import SwiftData

struct LearnView: View {
    @Environment(UserSettings.self) private var userSettings
    @Query(sort: \Course.order) private var courses: [Course]

    var onStartLesson: SingleResult<Lesson>?
    var onLockedLesson: VoidResult?
    var onChangeCourse: VoidResult?
    var onOpenPaywall: VoidResult?
    var onOpenStreak: VoidResult?

    private var course: Course? {
        courses.first { $0.remoteId == userSettings.selectedCourseId } ?? courses.first
    }

    var body: some View {
        VStack(spacing: 0) {
            LearnHeaderView(course: course,
                            onChangeCourse: onChangeCourse,
                            onTapHearts: onOpenPaywall,
                            onTapStreak: onOpenStreak)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            if let course {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 28) {
                            DailyQuestsCard()
                            ForEach(Array(course.sortedUnits.enumerated()), id: \.element.remoteId) { unitIndex, unit in
                                UnitSectionView(unit: unit,
                                                unitIndex: unitIndex,
                                                course: course,
                                                onTapLesson: handleTap)
                            }
                            comingSoon
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    .tabBarSafeArea()
                    .onAppear {
                        if let current = course.currentLesson {
                            proxy.scrollTo(current.remoteId, anchor: .center)
                        }
                    }
                }
            } else {
                Spacer()
                LoadingView(hideText: false)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
    }

    private func handleTap(_ lesson: Lesson) {
        guard let course else { return }
        if course.isUnlocked(lesson) {
            FeedbackService.tap()
            onStartLesson?(lesson)
        } else {
            onLockedLesson?()
        }
    }

    private var comingSoon: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(userSettings.theme.xpColor)
            Text("more_units_coming".localized())
                .setFont(.semibold, size: 15, color: userSettings.theme.secondaryTextColor, alignment: .center)
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Unit section

private struct UnitSectionView: View {
    @Environment(UserSettings.self) private var userSettings
    let unit: CourseUnit
    let unitIndex: Int
    let course: Course
    var onTapLesson: (Lesson) -> Void

    /// Horizontal offsets that create the winding path.
    private static let offsets: [CGFloat] = [0, 44, 70, 44, 0, -44, -70, -44]

    private var unitColor: Color {
        let palette = [userSettings.theme.primaryColor, userSettings.theme.correctShadowColor,
                       userSettings.theme.streakColor, Color(hex: "#0EA5E9"), Color(hex: "#EC4899")]
        return palette[unitIndex % palette.count]
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            ForEach(Array(unit.sortedLessons.enumerated()), id: \.element.remoteId) { index, lesson in
                let state = nodeState(for: lesson)
                LessonNodeView(lesson: lesson, state: state, color: unitColor)
                    .offset(x: Self.offsets[index % Self.offsets.count])
                    .id(lesson.remoteId)
                    .onTapGesture { onTapLesson(lesson) }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("unit_number".localizedFormat(unitIndex + 1).uppercased())
                    .setFont(.bold, size: 13, color: .white.opacity(0.85))
                Text(unit.title.text)
                    .setFont(.bold, size: 20, color: .white)
            }
            Spacer()
            Text("\(unit.completedCount)/\(unit.sortedLessons.count)")
                .setFont(.bold, size: 15, color: .white)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.white.opacity(0.2), in: Capsule())
        }
        .padding(16)
        .background(unitColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func nodeState(for lesson: Lesson) -> LessonNodeView.NodeState {
        if lesson.isCompleted { return .completed }
        if course.isUnlocked(lesson) { return .current }
        return .locked
    }
}

// MARK: - Lesson node

struct LessonNodeView: View {
    enum NodeState { case completed, current, locked }

    @Environment(UserSettings.self) private var userSettings
    let lesson: Lesson
    let state: NodeState
    let color: Color

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(state == .locked ? theme.secondaryTextColor : .white)
                .frame(width: 64, height: 64)
                .background(fillColor, in: Circle())
            Text(lesson.title.text)
                .setFont(state == .current ? .bold : .semibold, size: 13,
                         color: state == .locked ? theme.secondaryTextColor : theme.textColor,
                         alignment: .center)
                .lineLimit(1)
                .frame(maxWidth: 140)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var fillColor: Color {
        switch state {
        case .completed: return userSettings.theme.xpColor
        case .current: return color
        case .locked: return userSettings.theme.lockedColor
        }
    }

    private var iconName: String {
        switch state {
        case .completed: return "checkmark"
        case .current: return lesson.icon
        case .locked: return "lock.fill"
        }
    }
}

#Preview {
    LearnView()
        .environment(UserSettings())
        .environment(GamificationManager())
        .environment(PremiumManager())
        .modelContainer(PersistenceController.preview)
}
