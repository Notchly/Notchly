//
//  PreviewMusicView.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI
import AppKit

struct PreviewMusicView: View {
    let artwork: NSImage?
    let combinedPreviewText: String
    let waveformColor: Color
    let isPlaying: Bool
    let size: CGSize
    let skipIndicator: String?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Group {
                    if let artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                    }
                }

                Spacer()

                MusicWaveformView(
                    isPlaying: isPlaying,
                    color: waveformColor,
                    skipIndicator: skipIndicator
                )
                .frame(width: 36, height: 18)
            }

            HStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))

                MarqueeText(
                    text: combinedPreviewText,
                    font: .system(size: 12, weight: .medium),
                    nsFont: .systemFont(ofSize: 12, weight: .medium),
                    color: NSColor.white.withAlphaComponent(0.5),
                    speed: 18,
                    maxLength: nil,
                    maxRenderWidth: nil
                )
                .frame(width: 220, height: 16)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 12)
        .frame(width: size.width, height: size.height, alignment: .top)
        .foregroundStyle(.white)
    }
}
