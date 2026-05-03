//
//  MusicWaveformView.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI
import AppKit

struct MusicWaveformView: View {
    let isPlaying: Bool
    let color: Color
    let skipIndicator: String?

    var body: some View {
        ZStack {
            AnimatedWaveformView(
                isPlaying: isPlaying,
                color: NSColor(color)
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
