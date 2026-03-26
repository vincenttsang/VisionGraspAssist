//
//  SpeechManager.swift
//  VisionGraspAssist
//
//  Created by Vincent Tsang on 26/3/2026.
//

import AVFoundation
import SwiftUI
import Observation

@Observable
final class SpeechManager {

    private let synthesizer = AVSpeechSynthesizer()

    private var lastSpokenText: String?
    private var lastSpokenTime: Date = .distantPast

    /// 最短播報間隔（秒）
    private let cooldown: TimeInterval = 1.5

    func speakInstantly(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-HK")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func speakIfNeeded(_ text: String) {
        let now = Date()

        // ✅ 避免重複播報同一句
        if text == lastSpokenText {
            return
        }

        // ✅ 冷卻時間
        if now.timeIntervalSince(lastSpokenTime) < cooldown {
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-HK")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)

        lastSpokenText = text
        lastSpokenTime = now
    }

    /// 當重新開始時呼叫
    func reset() {
        synthesizer.stopSpeaking(at: .immediate)
        lastSpokenText = nil
        lastSpokenTime = .distantPast
    }
}
