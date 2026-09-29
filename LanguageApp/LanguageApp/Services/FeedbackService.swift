//
//  FeedbackService.swift
//  LanguageApp
//
//  Haptics + short system sounds for answer feedback.
//

import UIKit
import AudioToolbox

enum FeedbackService {
    static func correct(sound: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if sound { AudioServicesPlaySystemSound(1057) }
    }

    static func wrong(sound: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        if sound { AudioServicesPlaySystemSound(1053) }
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func celebrate(sound: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if sound { AudioServicesPlaySystemSound(1025) }
    }
}
