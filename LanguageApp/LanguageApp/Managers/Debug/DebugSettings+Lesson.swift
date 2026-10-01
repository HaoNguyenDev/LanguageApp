//
//  DebugSettings+Lesson.swift
//  LanguageApp
//
//  Applies the developer switches to lesson building. No effect in Release builds.
//

import Foundation

extension DebugSettings {
    /// Exercise generator with the developer switches applied.
    func lessonGenerator() -> ExerciseGenerator {
        var generator = ExerciseGenerator()
        generator.includesIntroCards = !skipsIntroCards
        generator.includesMatchPairs = !skipsMatchPairs
        switch forcedQuestionKind {
        case .chooseTerm: generator.forcedSecondPass = .chooseTerm
        case .listen: generator.forcedSecondPass = .listen
        case .typeTerm: generator.forcedSecondPass = .typeTerm
        case .typeListening: generator.forcedSecondPass = .typeListening
        case .buildSentence: generator.forcedSecondPass = .buildSentence
        case .mixed, .none: generator.forcedSecondPass = nil
        }
        return generator
    }

    /// Shortens a lesson's word list when "Short lessons" is on.
    func limitLessonWords<T>(_ words: [T]) -> [T] {
        guard let limit = lessonWordLimit else { return words }
        return Array(words.prefix(limit))
    }
}
