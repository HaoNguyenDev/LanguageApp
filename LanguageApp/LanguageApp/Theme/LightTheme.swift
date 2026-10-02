//
//  LightTheme.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

struct LightTheme: Theme {
    let bgColor = Color(hex: "#FFFFFF")
    let subviewBgColor = Color(hex: "#2B2D42")
    var textOnSubviewColor = Color(hex: "#FFFFFF")
    let gradientBgColors = [Color(hex: "#FFFFFF"), Color(hex: "#6C5CE7")]
    let textColor = Color(hex: "#2B2D42")
    let buttonBgColor = Color(hex: "#6C5CE7")
    let mainTabSelectedTextColor = Color(hex: "#FFFFFF")
    let mainTabUnselectedTextColor = Color(hex: "#AEAEB2")
    let tabBarSelectedColor = Color(hex: "#6C5CE7")
    let tabBarUnselectedColor = Color(hex: "#1C1C1E")
    let tabBarSelectedBgColor = Color.black.opacity(0.07)

    let primaryColor = Color(hex: "#6C5CE7")
    let primaryShadowColor = Color(hex: "#5245C9")
    let correctColor = Color(hex: "#22C55E")
    let correctShadowColor = Color(hex: "#16A34A")
    let correctBgColor = Color(hex: "#DCFCE7")
    let wrongColor = Color(hex: "#EF4444")
    let wrongShadowColor = Color(hex: "#DC2626")
    let wrongBgColor = Color(hex: "#FEE2E2")
    let xpColor = Color(hex: "#F59E0B")
    let streakColor = Color(hex: "#F97316")
    let heartColor = Color(hex: "#F43F5E")
    let cardBgColor = Color(hex: "#F3F4F8")
    let borderColor = Color(hex: "#E5E7EB")
    let secondaryTextColor = Color(hex: "#6B7280")
    let lockedColor = Color(hex: "#CBD5E1")
}
