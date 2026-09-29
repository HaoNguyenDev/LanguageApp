//
//  LanguageBadge.swift
//  LanguageApp
//
//  Round badge with a short language label ("VI", "EN", "中", "あ", "한", "ES").
//  Used instead of flag emoji: no image assets, and it renders the same on every device.
//

import SwiftUI

struct LanguageBadge: View {
    let text: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        Text(text)
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

extension LanguageBadge {
    /// Badge for a course being learned (`Course.remoteId`).
    init(courseId: String, size: CGFloat = 40) {
        let style = Self.style(for: courseId)
        self.init(text: style.text, color: style.color, size: size)
    }

    /// Badge for an app UI language.
    init(uiLanguage: LanguageCode, size: CGFloat = 40) {
        self.init(courseId: uiLanguage.courseId, size: size)
    }

    static func style(for courseId: String) -> (text: String, color: Color) {
        switch courseId {
        case "en": return ("EN", Color(hex: "#3B82F6"))
        case "zh": return ("中", Color(hex: "#EF4444"))
        case "ja": return ("あ", Color(hex: "#EC4899"))
        case "ko": return ("한", Color(hex: "#0EA5E9"))
        case "es": return ("ES", Color(hex: "#F59E0B"))
        case "vi": return ("VI", Color(hex: "#16A34A"))
        default: return (String(courseId.prefix(2)).uppercased(), Color(hex: "#6C5CE7"))
        }
    }
}

#Preview {
    HStack {
        ForEach(["en", "zh", "ja", "ko", "es"], id: \.self) { LanguageBadge(courseId: $0) }
    }
}
