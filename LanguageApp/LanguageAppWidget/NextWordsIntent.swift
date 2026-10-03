//
//  NextWordsIntent.swift
//  LanguageAppWidget
//
//  The ↻ button of the widget: shows the next words right away (WidgetKit reloads the
//  timeline after the intent runs). The rotation then continues from there with the clock.
//

import AppIntents
import WidgetKit

struct NextWordsIntent: AppIntent {
    static let title: LocalizedStringResource = "Next words"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WordWidgetData.advanceOffset()
        return .result()
    }
}
