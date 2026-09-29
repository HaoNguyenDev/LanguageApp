//
//  AppErrorCode.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//


import UIKit

enum AppErrorCode: Int, CaseIterable {
    case custom = -2
    case sectionExpired = 401
    case loginRequired = 200000
    case oauthTokenInvalid = 10015
    case notFound = 404
    case internalServerError = 500
    case emptyData = 1005
    case parseDataFailed = 1006
    case accountBlocked = 1007
    case accountBlockedByAdmin = 1008
    
    var message: String {
        switch self {
        case .loginRequired: return "Please log in to continue and enjoy the full App experience!"
        case .sectionExpired: return "Your session has expired. Please sign in again."
        case .accountBlocked: return "Please try again later"
        case .accountBlockedByAdmin: return "Please try again later"
        case .oauthTokenInvalid: return "Can not login with this account. Please try again later."
        default: return "Please try again later."
        }
    }

    var title: String {
        switch self {
        case .loginRequired: return "Login Required"
        case .sectionExpired: return "Your session has expired"
        case .accountBlocked: return "Your account is blocked"
        default: return "We are encountering some technical issues"
        }
    }
}

struct AppError: LocalizedError {
    static var unKnowErrorMessage: String {
        "We are encountering some technical issues"
    }

    var code: AppErrorCode
    var message: String

    init(code: Int, message: String? = nil) {
        self.code = AppErrorCode(rawValue: code) ?? .internalServerError
        if let goooCode = AppErrorCode(rawValue: code) {
            self.message = goooCode.message
        } else {
            self.message = message ?? "err_unknow"
        }
    }

    init(customMessage: String) {
        code = .custom
        message = customMessage
    }

    var errorDescription: String? {
        return message
    }
}
