//
//  WordWidgetService.swift
//  LanguageApp
//
//  Keeps the home-screen word widget in sync: same word pool and interval as the word
//  reminders, written to the App Group (see `WordWidgetData`). Called whenever notifications
//  are re-planned (launch, foreground, background, settings, new content).
//

import Foundation
import SwiftData
import WidgetKit

enum WordWidgetService {
    /// Rotation interval when word reminders are off.
    static let defaultInterval = 30

    static func update(in context: ModelContext, settings: UserSettings, now: Date = .now) {
        let course = NotificationManager.currentCourse(in: context, settings: settings)
        let pool = course.map { WordReminderPlanner.pool(courseId: $0.remoteId, in: context) } ?? []
        let data = snapshot(courseName: course?.name.text ?? "",
                            pool: pool,
                            intervalMinutes: settings.wordRemindersEnabled ? settings.wordReminderMinutes : defaultInterval,
                            texts: localizedTexts,
                            now: now)
        if data.save() {
            WidgetCenter.shared.reloadTimelines(ofKind: WordWidgetData.widgetKind)
        }
    }

    /// `updatedAt` only changes with the words, so an unchanged pool doesn't reload the widget.
    static func snapshot(courseName: String, pool: [ReminderWord], intervalMinutes: Int,
                         texts: WordWidgetData.Texts, now: Date,
                         previous: WordWidgetData? = WordWidgetData.load()) -> WordWidgetData {
        let words = pool.map {
            WordWidgetData.Word(id: $0.id, term: $0.term, reading: $0.reading, meaning: $0.meaning,
                                isHard: $0.isHard, level: $0.level)
        }
        let sameWords = previous?.words == words
        return WordWidgetData(courseName: courseName,
                              intervalMinutes: intervalMinutes,
                              words: words,
                              texts: texts,
                              updatedAt: sameWords ? (previous?.updatedAt ?? now) : now)
    }

    static var localizedTexts: WordWidgetData.Texts {
        WordWidgetData.Texts(title: "widget_words_title".localized(),
                             empty: "widget_words_empty".localized(),
                             hard: "widget_words_hard".localized(),
                             next: "widget_words_next".localized())
    }

    /// Developer menu.
    static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: WordWidgetData.widgetKind)
    }
}
