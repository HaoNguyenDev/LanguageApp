//
//  View+Additional.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

extension View {
    func setDefaultBackground() -> some View {
        modifier(BackgroundModifier())
    }
    
    func setGradientBackground(rotationColor: Bool = false) -> some View {
        modifier(GradientBackgroundModifier(rotationColor: rotationColor))
    }
    
    func setBlurBackgroundImage() -> some View {
        modifier(BackgroundImageModifier())
    }
}

// MARK: Modifiers
struct BackgroundModifier: ViewModifier {
    @Environment(UserSettings.self) var userSettings
    func body(content: Content) -> some View {
        content
            .background(
                ContainerRelativeShape()
                    .fill(userSettings.theme.bgColor)
                    .ignoresSafeArea(edges: .all)
            )
    }
}

struct GradientBackgroundModifier: ViewModifier {
    @Environment(UserSettings.self) var userSettings
    var rotationColor: Bool = false
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    gradient: Gradient(colors: getBackgroundColor(rotationColor: rotationColor) ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private func getBackgroundColor(rotationColor: Bool = false) -> [Color] {
        return rotationColor ? userSettings.theme.gradientBgColors.reversed() : userSettings.theme.gradientBgColors
    }
}

// MARK: Modifiers
struct BackgroundImageModifier: ViewModifier {
    @Environment(UserSettings.self) var userSettings
    func body(content: Content) -> some View {
        content
            .background(
                userSettings.theme.subviewBgColor.opacity(0.8) //Transparent color class
                    .overlay(BlurBackgroundView())
            )
        
        
    }
}
