//
//  AppVersion.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import Foundation

enum UpdateState {
    case nonUpdate
    case update
    case forceUpdate
}

struct AppVersion: Codable {
    let id: String
    let urlStore: String
    let version: String
    let osType: String
    let isForceUpdate: Bool
    let description: String?
    
    func checkUpdate(_ currentVersion: String) -> UpdateState {
        let compare = version.versionCompare(currentVersion)
        if compare == .orderedDescending {
            return isForceUpdate == true ? .forceUpdate : .update
        } else {
            return .nonUpdate
        }
    }
}
