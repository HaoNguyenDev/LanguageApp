//
//  CourseDTO.swift
//  LanguageApp
//
//  JSON schema for course content (bundled in Resources/Content, later downloadable).
//

import Foundation

struct CourseDTO: Decodable {
    let id: String
    let version: Int
    let name: LocalizedText
    let nativeName: String
    let flag: String
    let speechLocale: String
    let readingLabel: String?
    let units: [UnitDTO]
}

struct UnitDTO: Decodable {
    let id: String
    let title: LocalizedText
    let lessons: [LessonDTO]
}

struct LessonDTO: Decodable {
    let id: String
    let title: LocalizedText
    let icon: String?
    let xp: Int?
    /// Optional rule explained before the lesson (e.g. how numbers are built), in every UI language.
    let tip: LocalizedText?
    let items: [VocabItemDTO]
}

struct VocabItemDTO: Decodable {
    let id: String
    let term: String
    let reading: String?
    let meaning: LocalizedText
    let example: String?
    /// Chunks of `example` for the sentence builder (always present when `example` is).
    let exampleTokens: [String]?
    let exampleMeaning: LocalizedText?
}
