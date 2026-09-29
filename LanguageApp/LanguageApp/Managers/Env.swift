//
//  Env.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//


import Foundation

class Env {
    static let shared = Env()
    
    func getVersionApp() -> String {
        return (infoDict["CFBundleShortVersionString"] as? String).orEmpty
    }
    
    private let infoDict: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Plist file not found")
        }
        return dict
    }()
    
    private func value(for key:String) -> String {
        guard let value = infoDict[key] as? String else {
            fatalError("\(key) is not set in plist for this environment")
        }
        return value
    }
}
