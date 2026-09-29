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

    var body: some View {
        let theme = userSettings.theme
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenTitle(title: "choose_course".localized())
                    .padding(.bottom, 8)
                ForEach(courses) { course in
                    let isSelected = course.remoteId == userSettings.selectedCourseId
                    Button {
                        FeedbackService.tap()
                        userSettings.selectedCourseId = course.remoteId
                        onSelected?()
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
    }
}

#Preview {
    CourseSelectionView()
        .environment(UserSettings())
        .modelContainer(PersistenceController.preview)
}
