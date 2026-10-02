//
//  Theme.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

protocol Theme {
    // MARK: Base (from SwiftUI-BaseApp)
    var bgColor: Color { get }
    var subviewBgColor: Color { get }
    var textOnSubviewColor: Color { get }
    var gradientBgColors: [Color] { get }
    var textColor: Color { get }
    var buttonBgColor: Color { get }
    var mainTabSelectedTextColor: Color { get }
    var mainTabUnselectedTextColor: Color { get }

    // MARK: Tab bar (iOS 26 glass style)
    var tabBarSelectedColor: Color { get }
    var tabBarUnselectedColor: Color { get }
    /// Pill behind the selected tab.
    var tabBarSelectedBgColor: Color { get }

    // MARK: Learning / gamification
    var primaryColor: Color { get }
    var primaryShadowColor: Color { get }
    var correctColor: Color { get }
    var correctShadowColor: Color { get }
    var correctBgColor: Color { get }
    var wrongColor: Color { get }
    var wrongShadowColor: Color { get }
    var wrongBgColor: Color { get }
    var xpColor: Color { get }
    var streakColor: Color { get }
    /// Streak freeze (snowflake).
    var freezeColor: Color { get }
    var heartColor: Color { get }
    var cardBgColor: Color { get }
    var borderColor: Color { get }
    var secondaryTextColor: Color { get }
    var lockedColor: Color { get }
}
