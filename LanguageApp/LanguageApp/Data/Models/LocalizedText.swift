//
//  LocalizedText.swift
//  LanguageApp
//
//  Text translated into the app's UI languages (en / vi / zh / ja / ko / es).
//

import Foundation

struct LocalizedText: Codable, Hashable {
    var en: String
    var vi: String?
    var zh: String?
    var ja: String?
    var ko: String?
    var es: String?

    init(en: String, vi: String? = nil, zh: String? = nil, ja: String? = nil, ko: String? = nil, es: String? = nil) {
        self.en = en
        self.vi = vi
        self.zh = zh
        self.ja = ja
        self.ko = ko
        self.es = es
    }

    /// Resolves for a UI language code (`LanguageCode.rawValue`), falling back to English.
    func resolved(for uiLanguageCode: String) -> String {
        switch LanguageCode(rawValue: uiLanguageCode) {
        case .vi: return vi ?? en
        case .chs: return zh ?? en
        case .ja: return ja ?? en
        case .ko: return ko ?? en
        case .es: return es ?? en
        case .eng, .none: return en
        }
    }

    /// Resolved with the current UI language.
    var text: String {
        resolved(for: LanguageManager.shared.language.languageCode)
    }

    static let empty = LocalizedText(en: "")
}
