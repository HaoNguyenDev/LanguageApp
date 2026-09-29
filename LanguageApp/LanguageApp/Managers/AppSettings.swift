//
//  AppSettings.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import Foundation

@Observable final class AppSettings {
   
    var appVersion: AppVersion?
    
    var isMaintenance: Bool { false }
    
    var isNeedUpdate: Bool {
        return false
//        guard let appVersion = appVersion else { return false }
//        let state = appVersion.checkUpdate(Env.shared.getVersionApp())
//        return state != .nonUpdate
    }
}
