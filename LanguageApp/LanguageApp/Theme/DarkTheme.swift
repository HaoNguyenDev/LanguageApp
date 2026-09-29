//
//  DarkTheme.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

struct DarkTheme: Theme {
    let bgColor = Color(hex: "#131F24")
    let subviewBgColor = Color(hex: "#37464F")
    var textOnSubviewColor = Color(hex: "#FFFFFF")
    let gradientBgColors = [Color(hex: "#37464F"), Color(hex: "#000000")]
    let textColor = Color(hex: "#F1F5F9")
    let buttonBgColor = Color(hex: "#8B7CF6")
    let mainTabSelectedTextColor: Color = Color(hex: "#FFFFFF")
    let mainTabUnselectedTextColor: Color = Color(hex: "#AEAEB2")

    let primaryColor = Color(hex: "#8B7CF6")
    let primaryShadowColor = Color(hex: "#6C5CE7")
    let correctColor = Color(hex: "#4ADE80")
    let correctShadowColor = Color(hex: "#22C55E")
    let correctBgColor = Color(hex: "#14532D")
    let wrongColor = Color(hex: "#F87171")
    let wrongShadowColor = Color(hex: "#EF4444")
    let wrongBgColor = Color(hex: "#7F1D1D")
    let xpColor = Color(hex: "#FBBF24")
    let streakColor = Color(hex: "#FB923C")
    let heartColor = Color(hex: "#FB7185")
    let cardBgColor = Color(hex: "#1F2E35")
    let borderColor = Color(hex: "#37464F")
    let secondaryTextColor = Color(hex: "#94A3B8")
    let lockedColor = Color(hex: "#4B5563")
}
