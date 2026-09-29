//
//  BlurBackgroundView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 19/7/25.
//

import SwiftUI

struct BlurBackgroundView: View {
    @Environment(UserSettings.self) var userSettings
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ZStack {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 220))
                .foregroundStyle(userSettings.theme.primaryColor.opacity(0.35))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            BlurView(style: userSettings.colorSchemeOption == .system ? (colorScheme == .dark ? .dark : .light) : userSettings.colorSchemeOption == .dark ? .dark : .light) // .light, .dark, .extraLight...
                .ignoresSafeArea()
        }
    }
}
