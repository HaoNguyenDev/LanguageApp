//
//  SpeechService.swift
//  LanguageApp
//
//  Text-to-speech with the system voices (offline, free). Phase 2: native-speaker audio files.
//

import AVFoundation
import Observation

@Observable final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    func speak(_ text: String, locale: String, slow: Bool = false) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: locale)
        utterance.rate = slow ? AVSpeechUtteranceDefaultSpeechRate * 0.6 : AVSpeechUtteranceDefaultSpeechRate * 0.9
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    static func isVoiceAvailable(for locale: String) -> Bool {
        AVSpeechSynthesisVoice(language: locale) != nil
    }
}
