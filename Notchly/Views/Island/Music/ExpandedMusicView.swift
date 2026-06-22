//
//  ExpandedMusicView.swift
//  Notchly
//
//  Created by n0xbyte on 25.03.2026.
//

import SwiftUI
import AppKit

struct ExpandedMusicView: View {
    let artwork: NSImage?
    let artworkTransitionKey: String
    let title: String
    let artist: String
    let sourceName: String
    let isPlaying: Bool
    let isShuffleEnabled: Bool
    let isShuffleControlAvailable: Bool
    let isLivestream: Bool
    let waveformColor: Color
    let playbackPositionText: String
    let durationText: String
    let progress: CGFloat
    let outputVolume: Double
    let isOutputMuted: Bool
    let isVolumeControlExpanded: Bool
    let size: CGSize
    let playPauseBounce: Bool

    let onPreviewSeek: (CGFloat) -> Void
    let onSeek: (CGFloat) -> Void
    let onVolumeChange: (Double) -> Void
    let onToggleMute: () -> Void
    let onToggleVolumeControl: () -> Void
    let onToggleShuffle: () -> Void
    let onPrevious: () -> Void
    let onTogglePlay: () -> Void
    let onNext: () -> Void
    let onOpenSourceApp: () -> Void

    private var displayVolume: Double {
        isOutputMuted ? 0 : min(max(outputVolume, 0), 1)
    }

    private var volumeIconName: String {
        switch displayVolume {
        case ...0.01:
            return "speaker.slash.fill"
        case ..<0.34:
            return "speaker.wave.1.fill"
        case ..<0.67:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }

    private var shuffleIconColor: Color {
        guard isShuffleControlAvailable else {
            return .white.opacity(0.28)
        }

        return isShuffleEnabled ? waveformColor : .white.opacity(0.68)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Button(action: onOpenSourceApp) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        if let artwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .id(artworkTransitionKey)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 42, height: 42)

                                Image(systemName: "music.note")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .id("placeholder")
                            .transition(.opacity)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .animation(.easeInOut(duration: 0.28), value: artworkTransitionKey)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title.isEmpty ? "Now Playing" : title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(artist.isEmpty ? "Spotify" : artist)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(sourceName.isEmpty ? "Spotify" : sourceName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SubtleHoverButtonStyle(
                pressedScale: 0.98,
                hoverScale: 1.01,
                hoverBackgroundOpacity: 0.06,
                cornerRadius: 13
            ))

            VStack(spacing: 6) {
                if isLivestream {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)

                        Text("Livestream")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))

                        Spacer()
                    }
                    .frame(height: 20)
                    .padding(.horizontal, 2)
                } else {
                    MusicProgressView(
                        progress: progress,
                        waveformColor: waveformColor,
                        onPreviewSeek: onPreviewSeek,
                        onSeek: onSeek
                    )

                    HStack {
                        Text(playbackPositionText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))

                        Spacer()

                        Text(durationText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }

            HStack {
                Spacer()

                HStack(spacing: 16) {
                    Button(action: onToggleShuffle) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(shuffleIconColor)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .disabled(isLivestream || !isShuffleControlAvailable)
                    .buttonStyle(IslandControlButtonStyle())
                    .opacity((isLivestream || !isShuffleControlAvailable) ? 0.4 : 1.0)

                    Button(action: onPrevious) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                    }
                    .disabled(isLivestream)
                    .buttonStyle(IslandControlButtonStyle())
                    .opacity(isLivestream ? 0.4 : 1.0)

                    Button(action: onTogglePlay) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 38, height: 38)
                            .foregroundStyle(.white)
                            .scaleEffect(playPauseBounce ? 1.08 : 1.0)
                            .animation(.interactiveSpring(duration: 0.22, extraBounce: 0.22), value: playPauseBounce)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(IslandControlButtonStyle(pressedScale: 0.9))

                    Button(action: onNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                    }
                    .disabled(isLivestream)
                    .buttonStyle(IslandControlButtonStyle())
                    .opacity(isLivestream ? 0.4 : 1.0)

                    Button(action: onToggleVolumeControl) {
                        Image(systemName: volumeIconName)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white.opacity(isVolumeControlExpanded ? 1.0 : 0.78))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(IslandControlButtonStyle())
                }

                Spacer()
            }

            if isVolumeControlExpanded {
                MusicVolumeControl(
                    volume: outputVolume,
                    isMuted: isOutputMuted,
                    waveformColor: waveformColor,
                    onVolumeChange: onVolumeChange,
                    onToggleMute: onToggleMute
                )
                .transition(.opacity.combined(with: .offset(y: -6)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(width: size.width, height: size.height, alignment: .top)
        .foregroundStyle(.white)
    }
}

private struct MusicVolumeControl: View {
    let volume: Double
    let isMuted: Bool
    let waveformColor: Color
    let onVolumeChange: (Double) -> Void
    let onToggleMute: () -> Void

    private var displayVolume: Double {
        isMuted ? 0 : min(max(volume, 0), 1)
    }

    private var volumeIconName: String {
        switch displayVolume {
        case ...0.01:
            return "speaker.slash.fill"
        case ..<0.34:
            return "speaker.wave.1.fill"
        case ..<0.67:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleMute) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isMuted ? .white.opacity(0.45) : .white.opacity(0.86))
            }
            .buttonStyle(IslandControlButtonStyle())

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let fillWidth = width * displayVolume
                let scrollStep = 0.006

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 5)

                    Capsule()
                        .fill(isMuted ? Color.white.opacity(0.35) : waveformColor)
                        .frame(width: fillWidth, height: 5)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                        .offset(x: min(max(fillWidth - 5.5, 0), width - 11))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let nextVolume = min(max(value.location.x / width, 0), 1)
                            onVolumeChange(nextVolume)
                        }
                )
                .overlay(
                    ScrollSwipeCatcher { _, deltaY in
                        let nextVolume = min(max(displayVolume + (Double(deltaY) * scrollStep), 0), 1)
                        onVolumeChange(nextVolume)
                    }
                )
            }
            .frame(height: 24)

            Text("\(Int((displayVolume * 100).rounded()))%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 2)
    }
}
