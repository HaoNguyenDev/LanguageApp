//
//  ButtonStyle.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(mainFont.bold(16))
            .padding(.bottom, 4)
            .background(isEnabled ? Color(hex: "#0D00FF") : Color.gray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .circular))
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct PrimaryButtonStyleThin: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 17) {
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(mainFont.bold(12))
            .background(isEnabled ? Color(hex: "#0D00FF") : Color.gray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .circular))
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct PrimaryButtonStyleCustom: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let font: Font
    let cornerRadius: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .background(isEnabled ? Color(hex: "#0D00FF") : Color.gray)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .circular))
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}


struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(UserSettings.self) var userSettings
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(mainFont.bold(16))
            .background(Color.clear)
            .foregroundColor(isEnabled ? userSettings.theme.textColor : .gray)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isEnabled ? userSettings.theme.textColor : Color.gray, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct SecondaryButtonBlackStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    var radius: CGFloat = 16
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(mainFont.bold(12))
            .background(Color.clear)
            .foregroundColor(isEnabled ? Color(hex: "#333333") : .gray)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(isEnabled ? Color(hex: "#333333") : Color.gray, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct SecondaryButtonBlackStyleBig: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(mainFont.bold(16))
            .background(Color.clear)
            .foregroundColor(isEnabled ? Color(hex: "#333333") : .gray)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isEnabled ? Color(hex: "#333333") : Color.gray, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct TextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    var color: Color = Color.gray

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.clear)
            .foregroundColor(isEnabled ? color : Color.gray)
            .underline()
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

// For convenience, we can add extension to Button
extension Button {
    func primaryStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
            .environment(UserSettings())
    }
    
    func textStyle() -> some View {
        self.buttonStyle(TextButtonStyle())
    }
}

#Preview {
    VStack {
        Button("Hello, World!") {}
            .primaryStyle()
            .environment(\.isEnabled, true)
        Button("Hello, World!") {}
            .primaryStyle()
            .disabled(true)
        Button("Hello, World!") {}
            .secondaryStyle()
        Button("Hello, World!") {}
            .secondaryStyle()
            .disabled(true)
        Button("Hello, World!") {}
            .textStyle()
        Button("Hello, World!") {}
            .textStyle()
            .disabled(true)
    }
}
