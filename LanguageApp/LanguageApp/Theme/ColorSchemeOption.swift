//
//  ColorSchemeOption.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

enum ColorSchemeOption: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}
