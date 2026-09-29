//
//  WordListView.swift
//  LanguageApp
//
//  All learned words of a course with memory strength + search.
//

import SwiftUI
import SwiftData

struct WordListCoordinator: View {
    var navRouter: any NavRouterProtocol
    let courseId: String

    var body: some View {
        WordListView(courseId: courseId)
    }
}

struct WordListView: View {
    @Environment(UserSettings.self) private var userSettings
    @Query private var items: [VocabItem]
    @Query private var courses: [Course]
    @State private var searchText = ""

    init(courseId: String) {
        _items = Query(filter: #Predicate<VocabItem> { $0.courseId == courseId && $0.srsDue != nil },
                       sort: \VocabItem.term)
        _courses = Query(filter: #Predicate<Course> { $0.remoteId == courseId })
    }

    private var filtered: [VocabItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.term.lowercased().contains(query)
            || ($0.reading ?? "").lowercased().contains(query)
            || $0.meaning.text.lowercased().contains(query)
        }
    }

    var body: some View {
        let theme = userSettings.theme
        let locale = courses.first?.speechLocale ?? "en-US"
        List {
            ForEach(filtered) { item in
                HStack(spacing: 12) {
                    SpeakerButton(text: item.term, locale: locale, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.term).setFont(.bold, size: 18, color: theme.textColor)
                            if let reading = item.reading, !reading.isEmpty {
                                Text(reading).setFont(.regular, size: 13, color: theme.secondaryTextColor)
                            }
                        }
                        Text(item.meaning.text).setFont(.regular, size: 15, color: theme.secondaryTextColor)
                    }
                    Spacer()
                    StrengthIndicator(strength: item.strength)
                }
                .padding(.vertical, 4)
                .listRowBackground(theme.cardBgColor)
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "search_words".localized())
        .navigationTitle("words_learned".localized())
        .navigationBarTitleDisplayMode(.inline)
        .setDefaultBackground()
    }
}

struct StrengthIndicator: View {
    @Environment(UserSettings.self) private var userSettings
    let strength: WordStrength

    var body: some View {
        let theme = userSettings.theme
        let color: Color = {
            switch strength {
            case .new, .weak: return theme.wrongColor
            case .medium: return theme.xpColor
            case .strong: return theme.correctColor
            }
        }()
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...3, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level <= strength.bars ? color : theme.borderColor)
                    .frame(width: 5, height: CGFloat(6 + level * 5))
            }
        }
        .accessibilityLabel(strength.titleKey.localized())
    }
}
