//
//  AnswerMatcher.swift
//  LanguageApp
//
//  Grades typed answers leniently, like Duolingo:
//  - case, punctuation and extra spaces never matter;
//  - katakana and hiragana are interchangeable;
//  - romanized readings (Pinyin, Romaji, Korean romanization) are accepted without tones/macrons,
//    so learners don't need a Chinese/Japanese/Korean keyboard;
//  - a missing accent/tone mark or one typo in a Latin word is accepted as "almost" (the correct
//    spelling is shown).
//

import Foundation

enum AnswerMatcher {
    enum Result: Equatable {
        case correct
        /// Accepted, but the spelling should be shown (missing accent or one typo).
        case almost
        case wrong
    }

    static func grade(_ input: String, for item: StudyItem) -> Result {
        let typed = light(input)
        guard !typed.isEmpty else { return .wrong }

        if typed == light(item.term) { return .correct }

        let typedLoose = loose(input)
        let parts = readingParts(of: item)
        // Kana reading of a kanji word (e.g. "みず" for 水).
        if parts.native.contains(where: { light($0) == typed }) { return .correct }
        // Romanized reading without tones / macrons (e.g. "shui", "mizu", "mul").
        if parts.romanized.contains(where: { loose($0) == typedLoose }) { return .correct }

        let termLoose = loose(item.term)
        if typedLoose == termLoose { return .almost }
        if isLatin(termLoose), termLoose.count >= 5, levenshtein(typedLoose, termLoose) <= 1 { return .almost }
        return .wrong
    }

    // MARK: - Readings

    /// Splits "みず · mizu" into native (kana) and romanized parts. IPA readings ("/wɔːtər/") are ignored.
    static func readingParts(of item: StudyItem) -> (native: [String], romanized: [String]) {
        guard let reading = item.reading, !reading.isEmpty, !reading.hasPrefix("/") else { return ([], []) }
        var native: [String] = []
        var romanized: [String] = []
        for part in reading.split(separator: "·").map({ $0.trimmingCharacters(in: .whitespaces) }) where !part.isEmpty {
            if isLatin(loose(part)) {
                romanized.append(contentsOf: romajiVariants(part))
            } else {
                native.append(part)
            }
        }
        return (native, romanized)
    }

    /// "kyō" → ["kyō", "kyou", "kyoo"] so learners can type long vowels either way.
    private static func romajiVariants(_ text: String) -> [String] {
        let long: [Character: [String]] = ["ā": ["aa"], "ī": ["ii"], "ū": ["uu"], "ē": ["ee", "ei"], "ō": ["ou", "oo"]]
        guard text.contains(where: { long[$0] != nil }) else { return [text] }
        var variants = [text]
        for index in 0..<2 {
            var result = ""
            for char in text {
                if let options = long[char] { result += options[min(index, options.count - 1)] } else { result.append(char) }
            }
            variants.append(result)
        }
        return variants
    }

    // MARK: - Normalization

    /// Lowercase, katakana → hiragana, full-width ASCII → ASCII, no punctuation, single spaces.
    static func light(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.precomposedStringWithCanonicalMapping.lowercased().unicodeScalars {
            switch scalar.value {
            case 0x30A1...0x30F6:  // katakana → hiragana
                scalars.append(Unicode.Scalar(scalar.value - 0x60) ?? scalar)
            case 0xFF01...0xFF5E:  // full-width ASCII
                scalars.append(Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar)
            case 0x3000:           // ideographic space
                scalars.append(" ")
            default:
                scalars.append(scalar)
            }
        }
        let cleaned = String(scalars).filter { !$0.isPunctuation && !$0.isSymbol }
        return cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// `light` + accents/tones removed from Latin letters (not from kana or Hangul) + no spaces.
    static func loose(_ text: String) -> String {
        var result = ""
        for char in light(text) where !char.isWhitespace {
            if char == "đ" { result.append("d"); continue }
            let base = String(char).decomposedStringWithCanonicalMapping.unicodeScalars.first
            if let base, base.isASCII, base.properties.isAlphabetic {
                result.unicodeScalars.append(base)
            } else {
                result.append(char)
            }
        }
        return result
    }

    static func isLatin(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { $0.isASCII && ($0.properties.isAlphabetic || $0.properties.numericType != nil) }
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}
