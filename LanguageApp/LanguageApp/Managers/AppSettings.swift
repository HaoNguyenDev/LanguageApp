//
//  AppSettings.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import Foundation

@Observable final class AppSettings {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}

   
    var appVersion: AppVersion?
    
    var isMaintenance: Bool { false }
    
    var isNeedUpdate: Bool {
        return false
//        guard let appVersion = appVersion else { return false }
//        let state = appVersion.checkUpdate(Env.shared.getVersionApp())
//        return state != .nonUpdate
    }
}
