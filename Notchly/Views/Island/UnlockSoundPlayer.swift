//
//  UnlockSoundPlayer.swift
//  Notchly
//
//  Created by user on 03.04.2026.
//

import AppKit
import Foundation

@MainActor
final class UnlockSoundPlayer {
    static let shared = UnlockSoundPlayer()

    private var sound: NSSound?
    private var lastPlayDate: Date?

    private init() {
        if let url = Bundle.main.url(forResource: "Unlock", withExtension: "aiff") {
            sound = NSSound(contentsOf: url, byReference: true)
        } else if let url = Bundle.main.url(forResource: "Unlock", withExtension: "wav") {
            sound = NSSound(contentsOf: url, byReference: true)
        } else if let url = Bundle.main.url(forResource: "Unlock", withExtension: "mp3") {
            sound = NSSound(contentsOf: url, byReference: true)
        }

        sound?.volume = 0.15
    }

    func play(bypassThrottle: Bool = false) {
        guard let sound else { return }

        let now = Date()
        if !bypassThrottle, let lastPlayDate, now.timeIntervalSince(lastPlayDate) < 0.5 {
            return
        }

        if sound.isPlaying, !bypassThrottle {
            return
        }

        lastPlayDate = now
        sound.stop()
        sound.volume = 0.15
        sound.play()
    }
}
