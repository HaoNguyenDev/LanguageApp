//
//  UserMessageState.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI
import Lottie

// MARK: - UserMessageState
@Observable final class UserMessageState {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}

    var toastMessages = [UserMessageItem]()
    var alert: UserMessageItem?
    var informMessage: UserMessageItem?
    
    var isShowAlert: Binding<Bool> {
        Binding(
            get: { self.alert != nil },
            set: { newVal in
                if newVal == false {
                    self.alert = nil
                }
            }
        )
    }
    
    var isShowInform: Binding<Bool> {
        Binding(
            get: { self.informMessage != nil },
            set: { newVal in
                if newVal == false {
                    self.informMessage = nil
                }
            }
        )
    }
}


// MARK: - UserMessageState for Toast
extension UserMessageState {
    func showToast(item: UserMessageItem) {
        guard toastMessages.isEmpty else { return }
        toastMessages.append(item)
    }
    
    func hide() {
        guard toastMessages.count > 0 else { return }
        toastMessages.removeFirst()
    }
}

// MARK: - UserMessageState for Alert
extension UserMessageState {
    func showAlert(model: UserMessageItem?) {
        alert = model
    }
    
    func hideAlert() {
        alert = nil
    }
}

// MARK: - UserMessageState for informing
extension UserMessageState {
    func showInform(model: UserMessageItem?, autoDissmissAfter: TimeInterval? = 2) {
        guard informMessage == nil || model == nil else { return }
        informMessage = model
        
        if let dismissTime = autoDissmissAfter, model != nil {
            Task {
                try? await Task.sleep(for: .seconds(dismissTime))
                await MainActor.run {
                    // Only dismiss if it's still the same message
                    if self.informMessage == model {
                        self.informMessage = nil
                    }
                }
            }
        }
    }
}
