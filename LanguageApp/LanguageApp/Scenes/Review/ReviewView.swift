//
//  ReviewView.swift
//  LanguageApp
//
//  Spaced-repetition hub: due cards, learned words, strength breakdown.
//

import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(UserSettings.self) private var userSettings
    @Query(sort: \Course.order) private var courses: [Course]
    @Query(filter: #Predicate<VocabItem> { $0.srsDue != nil }) private var learnedItems: [VocabItem]

    var onStartReview: ((_ courseId: String, _ practice: Bool) -> Void)?
    var onPracticeWeakWords: SingleResult<String>?
    var onShowWords: SingleResult<String>?

    private var course: Course? {
        courses.first { $0.remoteId == userSettings.selectedCourseId } ?? courses.first
    }

    private var courseItems: [VocabItem] {
        guard let course else { return [] }
        return learnedItems.filter { $0.courseId == course.remoteId }
    }

    var body: some View {
        let theme = userSettings.theme
        let now = Date.now
        let dueCount = courseItems.filter { $0.isDue(at: now) }.count
        let nextDue = courseItems.compactMap(\.srsDue).filter { $0 > now }.min()

        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    ScreenTitle(title: "review_title".localized())
                    ReviewGuideButton()
                }

                // Hero card
                VStack(spacing: 14) {
                    Image(systemName: dueCount > 0 ? "rectangle.stack.fill" : "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(dueCount > 0 ? theme.primaryColor : theme.correctColor)
                    Text(dueCount > 0 ? "cards_due".localizedFormat(dueCount) : "no_cards_due".localized())
                        .setFont(.bold, size: 22, color: theme.textColor, alignment: .center)
                    if dueCount == 0, let nextDue {
                        HStack(spacing: 4) {
                            Text("next_review".localized())
                            Text(nextDue, style: .relative)
                        }
                        .font(mainFont.regular(15))
                        .foregroundStyle(theme.secondaryTextColor)
                    }
                    if courseItems.isEmpty {
                        Text("review_empty_message".localized())
                            .setFont(.regular, size: 15, color: theme.secondaryTextColor, alignment: .center)
                    } else if dueCount > 0 {
                        Button("start_review".localized()) {
                            if let course { onStartReview?(course.remoteId, false) }
                        }
                        .filled(theme.primaryColor)
                    } else {
                        Button("practice_anyway".localized()) {
                            if let course { onStartReview?(course.remoteId, true) }
                        }
                        .filled(theme.cardBgColor, foreground: theme.primaryColor)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(theme.cardBgColor.opacity(0.6), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(theme.borderColor, lineWidth: 2))

                strengthBreakdown

                if let course, courseItems.count >= PracticeService.minimumWords {
                    practiceWeakWordsCard(courseId: course.remoteId)
                }

                if let course, !courseItems.isEmpty {
                    Button {
                        onShowWords?(course.remoteId)
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text("all_words".localizedFormat(courseItems.count))
                                .font(mainFont.bold(16))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(theme.textColor)
                        .padding(18)
                        .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                howItWorks
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .tabBarSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
    }

    private var strengthBreakdown: some View {
        let theme = userSettings.theme
        let groups: [(WordStrength, Color)] = [(.weak, theme.wrongColor), (.medium, theme.xpColor), (.strong, theme.correctColor)]
        return HStack(spacing: 12) {
            ForEach(groups, id: \.0) { group in
                let (strength, color) = group
                VStack(spacing: 6) {
                    Text("\(courseItems.filter { $0.strength == strength }.count)")
                        .setFont(.bold, size: 24, color: color)
                    Text(strength.titleKey.localized())
                        .setFont(.semibold, size: 13, color: theme.secondaryTextColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func practiceWeakWordsCard(courseId: String) -> some View {
        let theme = userSettings.theme
        let wordCount = min(courseItems.count, PracticeService.sessionSize)
        return Button {
            onPracticeWeakWords?(courseId)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.wrongColor)
                    .frame(width: 48, height: 48)
                    .background(theme.wrongColor.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("practice_weak_words".localized())
                        .font(mainFont.bold(16))
                        .foregroundStyle(theme.textColor)
                    Text("practice_weak_words_message".localizedFormat(wordCount))
                        .font(mainFont.regular(13))
                        .foregroundStyle(theme.secondaryTextColor)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(theme.secondaryTextColor)
            }
            .padding(16)
            .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var howItWorks: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Label("srs_how_title".localized(), systemImage: "brain.head.profile")
                    .font(mainFont.bold(16))
                    .foregroundStyle(userSettings.theme.textColor)
                Text("srs_how_message".localized())
                    .setFont(.regular, size: 14, color: userSettings.theme.secondaryTextColor)
            }
        }
    }
}

#Preview {
    ReviewView()
        .environment(UserSettings())
        .modelContainer(PersistenceController.preview)
}
