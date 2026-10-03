//
//  UserMessageItem.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI
import UIKit
import Lottie

struct UserMessageItem: Equatable {
    enum DisplayType {
        case error
        case inform
        
        var color: Color {
            switch self {
            case .error:
                Color(hex: "#FC0F4D")
            case .inform:
                Color(hex: "#333333")
            }
        }
    }
    
    /// Identity of one shown message (queued toasts each get their own view and timer).
    let id = UUID()
    let icon: UIImage?
    let animation: (name: String, loop: LottieLoopMode)?
    let title: String?
    let message: String?
    let attributeMessage: AttributedString?
    let actionTitle: String?
    let type: DisplayType
    let code: AppErrorCode?
    let onClose: (() -> Void)?
    /// Seconds a toast stays on screen (nil = the default 3 s).
    var duration: TimeInterval?
    
    init(icon: UIImage? = nil,
         title: String? = nil,
         message: String? = nil,
         attributeMessage: AttributedString? = nil,
         actionTitle: String? = nil,
         displayType: DisplayType = .inform,
         code: AppErrorCode? = nil,
         onClose: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.animation = nil
        self.actionTitle = actionTitle
        self.type = displayType
        self.code = code
        self.attributeMessage = attributeMessage
        self.onClose = onClose
    }
    
    init(animationName: String,
         loopMode: LottieLoopMode = .loop,
         title: String? = nil,
         message: String? = nil,
         attributeMessage: AttributedString? = nil,
         actionTitle: String? = nil,
         displayType: DisplayType = .inform,
         code: AppErrorCode? = nil,
         onClose: (() -> Void)? = nil) {
        self.icon = nil
        self.title = title
        self.message = message
        self.animation = (name: animationName, loop: loopMode)
        self.actionTitle = actionTitle
        self.type = displayType
        self.code = code
        self.attributeMessage = attributeMessage
        self.onClose = onClose
    }
    
    /// A copy that stays long enough to read the whole text: ~15 characters a second
    /// on top of 2.5 s, between 5 and 10 s.
    func readable() -> UserMessageItem {
        var item = self
        item.duration = Self.readingDuration(for: [title, message].compactMap { $0 }.joined(separator: " "))
        return item
    }

    static func readingDuration(for text: String) -> TimeInterval {
        min(10, max(5, 2.5 + Double(text.count) / 15))
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
        && lhs.message == rhs.message
    }
}
