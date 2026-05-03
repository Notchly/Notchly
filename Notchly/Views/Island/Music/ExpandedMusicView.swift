//
//  ExpandedMusicView.swift
//  Notchly
//
//  Created by user on 25.03.2026.
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
    let isLivestream: Bool
    let waveformColor: Color
    let playbackPositionText: String
    let durationText: String
    let progress: CGFloat
    let size: CGSize
    let playPauseBounce: Bool

    let onPreviewSeek: (CGFloat) -> Void
    let onSeek: (CGFloat) -> Void
    let onPrevious: () -> Void
    let onTogglePlay: () -> Void
    let onNext: () -> Void
    let onOpenSourceApp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            .buttonStyle(.plain)

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
                    Button(action: onPrevious) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(isLivestream ? 0.04 : 0.08))
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(isLivestream ? 0.03 : 0.06), lineWidth: 1)
                            }
                    }
                    .disabled(isLivestream)
                    .buttonStyle(IslandControlButtonStyle())
                    .opacity(isLivestream ? 0.4 : 1.0)

                    Button(action: onTogglePlay) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 38, height: 38)
                            .background(Color.white)
                            .foregroundStyle(.black)
                            .clipShape(Circle())
                            .scaleEffect(playPauseBounce ? 1.08 : 1.0)
                            .animation(.interactiveSpring(duration: 0.22, extraBounce: 0.22), value: playPauseBounce)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(IslandControlButtonStyle(pressedScale: 0.9))

                    Button(action: onNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(isLivestream ? 0.04 : 0.08))
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(isLivestream ? 0.03 : 0.06), lineWidth: 1)
                            }
                    }
                    .disabled(isLivestream)
                    .buttonStyle(IslandControlButtonStyle())
                    .opacity(isLivestream ? 0.4 : 1.0)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(width: size.width, height: size.height, alignment: .top)
        .foregroundStyle(.white)
    }
}
