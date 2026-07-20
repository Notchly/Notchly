//
//  UnlockSoundPlayer.swift
//  Notchly
//
//  Created by n0xbyte on 03.04.2026.
//

import AVFAudio
import Foundation

@MainActor
final class UnlockSoundPlayer {
    static let shared = UnlockSoundPlayer()

    private var player: AVAudioPlayer?
    private var lastPlayDate: Date?

    private init() {
        let soundURL = ["aiff", "wav", "mp3"]
            .lazy
            .compactMap { Bundle.main.url(forResource: "Unlock", withExtension: $0) }
            .first

        guard let soundURL else { return }

        player = try? AVAudioPlayer(contentsOf: soundURL)
        player?.volume = 0.15
        player?.prepareToPlay()
    }

    func play(bypassThrottle: Bool = false) {
        guard let player else { return }

        let now = Date()
        if !bypassThrottle, let lastPlayDate, now.timeIntervalSince(lastPlayDate) < 0.5 {
            return
        }

        if player.isPlaying {
            guard bypassThrottle else { return }
            player.stop()
        }

        lastPlayDate = now
        player.currentTime = 0
        player.volume = 0.15
        player.prepareToPlay()
        player.play()
    }
}
