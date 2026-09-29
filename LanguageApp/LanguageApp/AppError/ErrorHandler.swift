//
//  ErrorHandler.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import Foundation

enum ErrorAction: Equatable {
    case alert
    case toast
    case log
    
    static func == (lhs: ErrorAction, rhs: ErrorAction) -> Bool {
        switch lhs {
        case .log:
            switch rhs {
            case .log:
                return true
            default:
                return false
            }
        case .alert:
            switch rhs {
            case .alert:
                return true
            default:
                return false
            }
        case .toast:
            switch rhs {
            case .toast:
                return true
            default:
                return false
            }
        }
    }
}

protocol ErrorHandler {
    func handle<T>(error: T?) -> UserMessageItem?
    func handleError<T>(error: T?, action: ErrorAction?)
}

extension ErrorHandler {
    func handle<T>(error: T?) -> UserMessageItem? {
        if let error = error as? AppError {
            return UserMessageItem(animationName: "Error", title: error.code.title, message: error.code.message, actionTitle: "I understand", code: error.code)
        } else if let errorMsg = error as? String {
            return UserMessageItem(animationName: "Error", title: nil, message: errorMsg)
        } else if let errCode = (error as? NSError)?.code {
                return UserMessageItem(animationName: "Error", title: nil, message: getErrorMessageBy(code: errCode, defaultMessage: (error as? NSError).debugDescription))
        } else {
            return UserMessageItem(animationName: "Error", title: nil, message: AppError.unKnowErrorMessage)
        }
    }
    
    private func getErrorMessageBy(code: Int, defaultMessage: String? = AppError.unKnowErrorMessage) -> String {
        switch code {
        default:
            return defaultMessage.orEmpty
        }
    }
}
