//
//  LanguageManager.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 15/7/25.
//


import Foundation

@Observable final class LanguageManager {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}

    static let shared = LanguageManager()
    private(set) var language: Language {
        didSet {
            loadLocalModel()
        }
    }
    
    private var localModel: LanguageJsonModel?
    var localVersion: Int { localModel?.version ?? 0 }

    let allSupportLanguages = LanguageCode.allCases.map { $0.getLanguage() }

    /// English strings used when a key is missing in the current language.
    private let fallbackModel: LanguageJsonModel? = {
        guard let url = Bundle.main.url(forResource: LanguageCode.eng.getLanguage().fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LanguageJsonModel.self, from: data)
    }()
    
    init() {
        language = LanguageCode.eng.getLanguage() //userSettings.getLanguage(languageCode).getLanguage()
        loadLocalModel()
    }
    
    func setLanguage(language: Language) {
        let selectedLanguage = allSupportLanguages.first(where: { $0.languageCode == language.languageCode }) ?? language
        self.language = selectedLanguage
        loadLocalModel()
    }

    func valueForKey(_ key: String) -> String {
        return localModel?.data[key] ?? fallbackModel?.data[key] ?? key
    }

    // MARK: - Private
    private func loadLocalModel() {
        guard let url = Bundle.main.url(forResource: language.fileName, withExtension: "json") else {
            Logger.shared.error("❌ File not found for language: \(language.fileName)")
            localModel = nil
            return
        }
        do {
            let data = try Data(contentsOf: url)
            localModel = try JSONDecoder().decode(LanguageJsonModel.self, from: data)
        } catch {
            Logger.shared.error("❌ Failed to load or parse JSON for language \(language.languageCode): \(error)")
            localModel = nil
        }
    }
}
