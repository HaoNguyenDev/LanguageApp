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
    var onStartCheckpoint: SingleResult<CourseUnit>?
    /// Tapped something locked; the parameter is the key of the message to show.
    var onLocked: StringResult?
    var onChangeCourse: VoidResult?
    var onOpenPaywall: VoidResult?
    var onOpenStreak: VoidResult?

    /// Id of the section at the top of the screen (quests card, a unit, "coming soon"), kept by
    /// `scrollPosition` – changes only when another section reaches the top, not on every frame.
    @State private var topSectionId: String?
    /// Units whose header is on screen (pinned at the top or scrolling by) – the unit button stays
    /// hidden while its unit's header can be seen.
    @State private var unitsWithVisibleHeader: Set<String> = []

    static let questsId = "learn-quests"
    static let comingSoonId = "learn-coming-soon"

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
                // All scrolling goes through `topSectionId` (scrollPosition), never a
                // ScrollViewReader: a proxy scroll doesn't update the binding, which left the
                // buttons reading a stale position (↑ shown at the top, unit button pointing up).
                ScrollView(showsIndicators: false) {
                    // Unit headers stick to the top while their unit is on screen.
                    LazyVStack(spacing: 28, pinnedViews: [.sectionHeaders]) {
                        DailyQuestsCard()
                            .id(Self.questsId)
                        ForEach(Array(course.sortedUnits.enumerated()), id: \.element.remoteId) { unitIndex, unit in
                            UnitSectionView(unit: unit,
                                            unitIndex: unitIndex,
                                            course: course,
                                            onTapLesson: handleTap,
                                            onTapCheckpoint: handleCheckpointTap,
                                            onHeaderVisibilityChange: { isVisible in
                                                if isVisible {
                                                    unitsWithVisibleHeader.insert(unit.remoteId)
                                                    } else {
                                                        unitsWithVisibleHeader.remove(unit.remoteId)
                                                    }
                                                })
                        }
                        comingSoon
                            .id(Self.comingSoonId)
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .scrollPosition(id: $topSectionId, anchor: .top)
                .onChange(of: topSectionId) { _, top in
                    pruneHeaderVisibility(top: top, unitIds: course.sortedUnits.map(\.remoteId))
                }
                .overlay(alignment: .bottomTrailing) {
                    scrollButtons(course: course)
                }
                .tabBarSafeArea()
                .onAppear {
                    // Open on the unit being learned (Unit 1 → stay at the top with the quests).
                    guard topSectionId == nil, let unit = course.currentLesson?.unit,
                          unit.remoteId != course.sortedUnits.first?.remoteId else { return }
                    Task { topSectionId = unit.remoteId }
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

    // MARK: - Scroll buttons

    /// Floating buttons above the tab bar: back to the top, and to the unit of the furthest completed lesson.
    private func scrollButtons(course: Course) -> some View {
        let theme = userSettings.theme
        let units = course.sortedUnits
        let latestUnit = course.furthestCompletedUnit
        let unitNumber = latestUnit.flatMap { unit in units.firstIndex { $0.remoteId == unit.remoteId } }
        let visibility = Self.scrollButtonVisibility(topSectionId: topSectionId,
                                                     unitIds: units.map(\.remoteId),
                                                     targetUnitIndex: unitNumber,
                                                     targetHeaderOnScreen: latestUnit.map { unitsWithVisibleHeader.contains($0.remoteId) } ?? false)
        let showsTop = visibility.top
        return VStack(alignment: .trailing, spacing: 10) {
            if showsTop {
                Button {
                    FeedbackService.tap()
                    withAnimation(.easeInOut(duration: 0.4)) { topSectionId = Self.questsId }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.textOnSubviewColor)
                        .frame(width: 48, height: 48)
                        .background(theme.subviewBgColor, in: .circle)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .accessibilityLabel("scroll_to_top".localized())
                .transition(.scale.combined(with: .opacity))
            }
            if let direction = visibility.unit, let latestUnit, let unitNumber {
                Button {
                    FeedbackService.tap()
                    withAnimation(.easeInOut(duration: 0.4)) { topSectionId = latestUnit.remoteId }
                } label: {
                    // The arrow tells where the unit is: below (after ↑) or above (scrolled past it).
                    Label("unit_number".localizedFormat(unitNumber + 1),
                          systemImage: direction == .down ? "arrow.down" : "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(theme.primaryColor, in: .capsule)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .accessibilityLabel("scroll_to_latest_unit".localizedFormat(unitNumber + 1))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.trailing, 16)
        // Above the tab bar (80 pt, see `tabBarSafeArea`).
        .padding(.bottom, 92)
        .animation(.spring(duration: 0.3), value: visibility)
    }

    /// A fast scroll can skip the "went off screen" report of a header. Headers can only be on
    /// screen from the unit at the top to a couple of units below it, so anything else is dropped.
    private func pruneHeaderVisibility(top: String?, unitIds: [String]) {
        let topIndex = top.flatMap { unitIds.firstIndex(of: $0) } ?? (top == Self.comingSoonId ? unitIds.count : -1)
        let kept = unitsWithVisibleHeader.filter { id in
            guard let index = unitIds.firstIndex(of: id) else { return false }
            return index >= topIndex && index <= topIndex + 2
        }
        if kept != unitsWithVisibleHeader { unitsWithVisibleHeader = kept }
    }

    /// Which floating buttons to show for the section at the top of the screen.
    /// - top: from Unit 2 on (hidden on the quests card and in Unit 1).
    /// - unit: hidden while the header of the unit of the furthest completed lesson is on screen
    ///   (pinned at the top because the learner is in it, or scrolling by); otherwise `.up` when
    ///   scrolled past it, `.down` when above it (e.g. after ↑).
    static func scrollButtonVisibility(topSectionId: String?, unitIds: [String], targetUnitIndex: Int?,
                                       targetHeaderOnScreen: Bool = false) -> ScrollButtonVisibility {
        let topIndex: Int? = topSectionId == comingSoonId ? unitIds.count : topSectionId.flatMap { unitIds.firstIndex(of: $0) }
        // Never while the learner is at the top or in Unit 1 (the top is right there).
        let showsTop = (topIndex ?? 0) >= 1
        guard let targetUnitIndex else { return ScrollButtonVisibility(top: showsTop, unit: nil) }
        // Quests card / not scrolled yet = above every unit.
        let position = topIndex ?? -1
        // Past the unit its header can't be on screen (only the current unit's header is pinned),
        // so a visibility report that a fast scroll left behind is ignored there.
        if targetHeaderOnScreen && position <= targetUnitIndex {
            return ScrollButtonVisibility(top: showsTop, unit: nil)
        }
        let unit: ScrollButtonVisibility.Direction? = position > targetUnitIndex ? .up
            : position < targetUnitIndex ? .down : nil
        return ScrollButtonVisibility(top: showsTop, unit: unit)
    }

    struct ScrollButtonVisibility: Equatable {
        enum Direction { case up, down }
        let top: Bool
        /// nil = hidden (the learner is in that unit).
        let unit: Direction?
    }

    private func handleTap(_ lesson: Lesson) {
        guard let course else { return }
        if course.isUnlocked(lesson) {
            FeedbackService.tap()
            onStartLesson?(lesson)
        } else {
            onLocked?(course.isWaitingForCheckpoint(lesson) ? "lesson_locked_checkpoint_message" : "lesson_locked_message")
        }
    }

    private func handleCheckpointTap(_ unit: CourseUnit) {
        if unit.isCheckpointUnlocked {
            FeedbackService.tap()
            onStartCheckpoint?(unit)
        } else {
            onLocked?("checkpoint_locked_message")
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
    var onTapCheckpoint: (CourseUnit) -> Void
    /// The unit header came on / went off screen.
    var onHeaderVisibilityChange: (Bool) -> Void = { _ in }

    /// Horizontal offsets that create the winding path.
    private static let offsets: [CGFloat] = [0, 44, 70, 44, 0, -44, -70, -44]

    private var unitColor: Color {
        let palette = [userSettings.theme.primaryColor, userSettings.theme.correctShadowColor,
                       userSettings.theme.streakColor, Color(hex: "#0EA5E9"), Color(hex: "#EC4899")]
        return palette[unitIndex % palette.count]
    }

    var body: some View {
        // A section of the pinned LazyVStack: the header sticks while the unit scrolls under it.
        Section {
            lessonPath
        } header: {
            pinnedHeader
                .onVisibleOnScreen(onHeaderVisibilityChange)
        }
    }

    /// Opaque band behind the header so the path doesn't show around it while pinned.
    private var pinnedHeader: some View {
        header
            .padding(.vertical, 6)
            .background {
                userSettings.theme.bgColor
                    .padding(.horizontal, -20) // the stack's side padding
            }
    }

    private var lessonPath: some View {
        VStack(spacing: 20) {
            ForEach(Array(unit.sortedLessons.enumerated()), id: \.element.remoteId) { index, lesson in
                let state = nodeState(for: lesson)
                LessonNodeView(lesson: lesson, state: state, color: unitColor)
                    .offset(x: Self.offsets[index % Self.offsets.count])
                    .id(lesson.remoteId)
                    .onTapGesture { onTapLesson(lesson) }
            }
            CheckpointNodeView(state: checkpointState, color: unitColor)
                .id("checkpoint-\(unit.remoteId)")
                .onTapGesture { onTapCheckpoint(unit) }
        }
    }

    private var checkpointState: CheckpointNodeView.NodeState {
        if unit.checkpointPassed { return .passed }
        if unit.isCheckpointUnlocked { return .available }
        return .locked
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

// MARK: - Checkpoint node

struct CheckpointNodeView: View {
    enum NodeState { case passed, available, locked }

    @Environment(UserSettings.self) private var userSettings
    let state: NodeState
    let color: Color

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 8) {
            Image(systemName: state == .locked ? "lock.fill" : "trophy.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(state == .locked ? theme.secondaryTextColor : .white)
                .frame(width: 76, height: 76)
                .background(fillColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if state == .passed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, theme.correctColor)
                            .offset(x: 6, y: 6)
                    }
                }
            Text("checkpoint".localized())
                .setFont(state == .available ? .bold : .semibold, size: 13,
                         color: state == .locked ? theme.secondaryTextColor : theme.textColor,
                         alignment: .center)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var fillColor: Color {
        switch state {
        case .passed: return userSettings.theme.xpColor
        case .available: return color
        case .locked: return userSettings.theme.lockedColor
        }
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
            // Always the lesson's own icon: dimmed until it's reached, a green tick once done
            // (like the passed checkpoint).
            Image(systemName: lesson.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 64, height: 64)
                .background(fillColor, in: Circle())
                .overlay(alignment: .bottomTrailing) {
                    if state == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, theme.correctColor)
                            .offset(x: 4, y: 4)
                    }
                }
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

    /// Locked: the unit color, faded, on the grey circle – recognizable but clearly not reached yet.
    private var iconColor: Color {
        state == .locked ? color.opacity(0.45) : .white
    }
}

#Preview {
    LearnView()
        .environment(UserSettings())
        .environment(GamificationManager())
        .environment(PremiumManager())
        .modelContainer(PersistenceController.preview)
}

private extension View {
    /// Reports when the view comes on / goes off screen inside a scroll view. iOS 18 measures the
    /// visible part (10 % is enough); iOS 17 falls back to the lazy stack loading / unloading it,
    /// which happens a little before it actually scrolls into view.
    @ViewBuilder
    func onVisibleOnScreen(_ action: @escaping (Bool) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollVisibilityChange(threshold: 0.1, action)
        } else {
            onAppear { action(true) }
                .onDisappear { action(false) }
        }
    }
}
