//
//  MusicWaveformView.swift
//  Notchly
//
//  Created by n0xbyte on 25.03.2026.
//

import SwiftUI

struct MusicWaveformView: View {
    let isPlaying: Bool
    let color: Color
    let skipIndicator: String?

    var body: some View {
        ZStack {
            EqualizerGlyph(
                isActive: isPlaying,
                color: color,
                idleHeights: [4, 5, 4, 6, 4, 5],
                activeHeights: [8, 14, 10, 16, 11, 9],
                phaseOffsets: [0.0, 1.1, 2.2, 0.6, 1.7, 2.8],
                barWidth: 2,
                spacing: 3,
                speed: 4.8
            )
            .frame(height: 18)
            .opacity(skipIndicator == nil ? 1 : 0.18)
            .scaleEffect(skipIndicator == nil ? 1 : 0.9)

            if let skipIndicator {
                Image(systemName: skipIndicator)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: skipIndicator)
    }
}
