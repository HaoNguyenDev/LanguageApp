//
//  Text+Additional.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

extension Text {
    func setFont(_ font: Nunito.FontName, size: CGFloat, color: Color, alignment: TextAlignment = .leading) -> some View {
        modifier(FontSizeColorModifier(font: font, size: size, color: color, alignment: alignment))
    }
}

// MARK: Modifiers
struct FontSizeColorModifier: ViewModifier {
    var font: Nunito.FontName
    var size: CGFloat
    var color: Color
    var alignment: TextAlignment = .leading
    
    func body(content: Content) -> some View {
        content
            .font(mainFont.fontName(font, size))
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
    }
}
