//
//  CourseSelectionView.swift
//  LanguageApp
//

import SwiftUI
import SwiftData

struct CourseSelectionCoordinator: View {
    var navRouter: any NavRouterProtocol

    var body: some View {
        CourseSelectionView(onSelected: { navRouter.pop(animate: true) })
    }
}

struct CourseSelectionView: View {
    @Environment(UserSettings.self) private var userSettings
    @Query(sort: \Course.order) private var courses: [Course]
    var onSelected: VoidResult?

    /// Course waiting for confirmation because it teaches the app's own UI language.
    @State private var pendingCourse: Course?

    var body: some View {
        let theme = userSettings.theme
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenTitle(title: "choose_course".localized())
                    .padding(.bottom, 8)
                ForEach(courses) { course in
                    let isSelected = course.remoteId == userSettings.selectedCourseId
                    let isSameAsUI = course.isSameLanguage(asUILanguage: userSettings.languageCode)
                    Button {
                        FeedbackService.tap()
                        if isSameAsUI && !isSelected {
                            pendingCourse = course
                        } else {
                            select(course)
                        }
                    } label: {
                        HStack(spacing: 16) {
                            LanguageBadge(courseId: course.remoteId, size: 48)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(course.name.text)
                                        .setFont(.bold, size: 18, color: theme.textColor)
                                    Text(course.nativeName)
                                        .setFont(.regular, size: 14, color: theme.secondaryTextColor)
                                }
                                LessonProgressBar(progress: course.progress, height: 10, color: theme.xpColor)
                                Text("lessons_progress".localizedFormat(course.completedLessonCount, course.orderedLessons.count))
                                    .setFont(.regular, size: 12, color: theme.secondaryTextColor)
                                if isSameAsUI {
                                    Label("same_as_app_language".localized(), systemImage: "exclamationmark.triangle.fill")
                                        .font(mainFont.semibold(12))
                                        .foregroundStyle(theme.wrongColor)
                                }
                            }
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(theme.primaryColor)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(OptionButtonStyle(state: isSelected ? .selected : .normal))
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .alert("same_language_title".localized(),
               isPresented: Binding(get: { pendingCourse != nil }, set: { if !$0 { pendingCourse = nil } }),
               presenting: pendingCourse) { course in
            Button("continue_anyway".localized()) { select(course) }
            Button("cancel".localized(), role: .cancel) {}
        } message: { course in
            Text("same_language_message".localizedFormat(course.name.text, course.name.text))
        }
    }

    private func select(_ course: Course) {
        userSettings.selectedCourseId = course.remoteId
        onSelected?()
    }
}

#Preview {
    CourseSelectionView()
        .environment(UserSettings())
        .modelContainer(PersistenceController.preview)
}
