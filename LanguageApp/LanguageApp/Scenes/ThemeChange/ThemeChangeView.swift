//
//  ThemeChangeView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 13/7/25.
//


import SwiftUI

struct ThemeChangeView: View {
    @Environment(UserSettings.self) var userSettings
    @Environment(\.colorScheme) var systemColorScheme
    @Namespace private var animation
    private var isDarkMode: Bool = false
    var body: some View {
        VStack(spacing: 15) {
            Text("choose_theme".localized())
                .setFont(.bold, size: 25, color: userSettings.theme.textOnSubviewColor)
            
            Image(systemName: themeIcon(userSettings.colorSchemeOption))
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(userSettings.theme.bgColor)
            
            Text("\("current_theme".localized()) \(userSettings.colorSchemeOption.title)")
                .setFont(.regular, size: 17, color: userSettings.theme.textOnSubviewColor)
            Text("choose_theme".localized())
                .setFont(.regular, size: 17, color: userSettings.theme.textOnSubviewColor)
            
            HStack(spacing: 0) {
                ForEach(ColorSchemeOption.allCases, id: \.self) { theme in
                    Text(theme.rawValue)
                        .setFont(.semibold, size: 17, color: userSettings.colorSchemeOption == theme ? userSettings.theme.textColor : userSettings.theme.textOnSubviewColor)
                        .padding(.vertical, 10)
                        .frame(width: 100)
                        .background {
                            ZStack {
                                if userSettings.colorSchemeOption == theme {
                                    Capsule()
                                        .fill(userSettings.theme.bgColor)
                                        .matchedGeometryEffect(id: "ACTIVETAB", in: animation)
                                }
                            }
                            .animation(.snappy, value: userSettings.colorSchemeOption)
                        }
                        .contentShape(.rect)
                        .onTapGesture {
                            updateTheme(scheme: theme)
                        }
                }
            }
            .padding(5)
            .background(userSettings.theme.mainTabUnselectedTextColor.opacity(0.3), in: .capsule)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 410)
        .background {
            userSettings.theme.subviewBgColor
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 10)
        .onAppear {
        }
        
    }
    
    
    private func themeIcon(_ theme: ColorSchemeOption) -> String {
        switch theme {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "autostartstop.trianglebadge.exclamationmark"
        }
    }
  
    private func updateTheme(scheme: ColorSchemeOption) {
        userSettings.setColorScheme(scheme, systemColorScheme: systemColorScheme)
    }
}

#Preview {
    ThemeChangeView()
        .environment(UserSettings())
        .colorScheme(.light)
}
