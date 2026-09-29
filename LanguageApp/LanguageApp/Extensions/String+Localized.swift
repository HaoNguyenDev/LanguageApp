//
//  String+Localized.swift
//  LanguageApp
//

import Foundation

extension String {
    /// Localized string with `String(format:)` arguments, e.g. "xp_earned".localizedFormat(15)
    func localizedFormat(_ args: CVarArg...) -> String {
        String(format: self.localized(), arguments: args)
    }
}
