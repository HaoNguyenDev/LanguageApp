//
//  AppState.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import Foundation
import Combine

actor LoadingCounter {
    var count: Int = 0
    
    func increase() {
        count += 1
    }
    
    func decrease() {
        count -= 1
        if count < 0 {
            count = 0
        }
    }
}

@Observable class AppState: ErrorHandler {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}

    // MARK: - Loading
    var isShowLoading = false
    
    var isShowDrawingCoin = false
    
    /// ObservationIgnored
    private var loadingCounter = LoadingCounter()
    // MARK: - Message
    var userMessageState = UserMessageState()
    
    init() {}
    
    @MainActor
    func showLoading() async {
        await loadingCounter.increase()
        if !isShowLoading {
            isShowLoading = true
        }
    }
    
    @MainActor
    func hideLoading() async {
        await loadingCounter.decrease()
        if await loadingCounter.count == 0 {
            isShowLoading = false
        }
    }
    
    func showToast(item: UserMessageItem) {
        userMessageState.showToast(item: item)
    }
    
    func showAlert(alertData: UserMessageItem) {
        userMessageState.showAlert(model: alertData)
    }
    
    func showInform(message: UserMessageItem, autoDissmissAfter: TimeInterval? = 3) {
        userMessageState.showInform(model: message)
    }
    
    func handleError<T>(error: T?, action: ErrorAction? = .log) {
        guard let data = self.handle(error: error) else { return }
        switch action {
        case .toast:
            showToast(item: data)
        case .alert:
            showAlert(alertData: data)
        default:
            print(data.message.orEmpty)
            Logger.shared.error(data.message.orEmpty)
        }
    }
    
}
