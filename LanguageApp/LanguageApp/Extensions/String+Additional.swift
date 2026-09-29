//
//  String+Additional.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import UIKit

// Extension for Optional String to provide a default empty string
extension Optional where Wrapped == String {
    var orEmpty: String {
        switch self {
        case .some(let value):
            return String(describing: value)
        default:
            return ""
        }
    }
}

extension String {
    var isNotEmpty: Bool {
        return !isEmpty
    }
}

// Extension for String to compare version numbers
extension String {
    func versionCompare(_ otherVersion: String) -> ComparisonResult {
        let versionDelimiter = "."

        // Split version strings into components
        var versionComponents = self.components(separatedBy: versionDelimiter)
        var otherVersionComponents = otherVersion.components(separatedBy: versionDelimiter)

        // Calculate the difference in component count
        let zeroDiff = versionComponents.count - otherVersionComponents.count

        if zeroDiff == 0 {
            // Same format, compare normally
            return self.compare(otherVersion, options: .numeric)
        } else {
            // Append zeros to the shorter version
            let zeros = Array(repeating: "0", count: abs(zeroDiff))
            if zeroDiff > 0 {
                otherVersionComponents.append(contentsOf: zeros)
            } else {
                versionComponents.append(contentsOf: zeros)
            }
            return versionComponents.joined(separator: versionDelimiter)
                .compare(
                    otherVersionComponents.joined(separator: versionDelimiter), options: .numeric)
        }
    }
}

// Extension for get language
extension String {
    func localized() -> String {
        return LanguageManager.shared.valueForKey(self.lowercased())
    }
}
