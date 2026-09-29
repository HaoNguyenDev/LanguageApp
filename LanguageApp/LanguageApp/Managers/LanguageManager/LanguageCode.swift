//
//  LanguageCode.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 15/7/25.
//

import Foundation

public struct LanguageJsonModel: Codable {
    public var version: Int
    public var data: [String: String]

    enum CodingKeys: String, CodingKey {
        case version = "version"
        case data = "data"
    }
}

/// App UI language (not the language being learned – see `Course`).
/// The app offers the same 6 languages for the UI and for learning.
enum LanguageCode: String, CaseIterable, TitleItem {
    case vi
    case eng
    case chs
    case ja
    case ko
    case es

    var title: String {
        switch self {
        case .vi: return "Tiếng Việt"
        case .eng: return "English"
        case .chs: return "中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .es: return "Español"
        }
    }

    /// Matching `Course.remoteId` of the same language.
    var courseId: String {
        switch self {
        case .vi: return "vi"
        case .eng: return "en"
        case .chs: return "zh"
        case .ja: return "ja"
        case .ko: return "ko"
        case .es: return "es"
        }
    }

    /// Picks the UI language from the device's preferred languages.
    static var deviceDefault: LanguageCode {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("vi") { return .vi }
        if preferred.hasPrefix("zh") { return .chs }
        if preferred.hasPrefix("ja") { return .ja }
        if preferred.hasPrefix("ko") { return .ko }
        if preferred.hasPrefix("es") { return .es }
        return .eng
    }

    func getLanguage() -> Language {
        let fileName: String
        switch self {
        case .vi: fileName = "lang_vi"
        case .eng: fileName = "lang_en"
        case .chs: fileName = "lang_cn"
        case .ja: fileName = "lang_ja"
        case .ko: fileName = "lang_ko"
        case .es: fileName = "lang_es"
        }
        return Language(displayName: title, languageCode: rawValue, flagName: courseId, fileName: fileName)
    }
}

struct Language: Codable {
    var displayName: String
    var languageCode: String
    var flagName: String
    var fileName: String

    init(displayName: String, languageCode: String, flagName: String, fileName: String) {
        self.displayName = displayName
        self.languageCode = languageCode
        self.flagName = flagName
        self.fileName = fileName
    }

    var isChinaLanguage: Bool {
        return languageCode == LanguageCode.chs.rawValue
    }
}
