//
//  LockScreenMusicPlayerView.swift
//  Notchly
//
//  Created by user on 14.05.2026.
//

import SwiftUI
import AppKit

struct LockScreenMusicPlayerView: View {
    @ObservedObject var musicManager: MusicManager
    let isVisible: Bool

    @State private var playPauseBounce = false

    private var isLivestream: Bool {
        musicManager.durationMs <= 0
    }

    private var progress: CGFloat {
        guard musicManager.durationMs > 0 else { return 0 }
        return CGFloat(min(max(musicManager.playbackPosition / musicManager.durationMs, 0), 1))
    }

    private var displayTitle: String {
        musicManager.trackTitle.isEmpty ? "Now Playing" : musicManager.trackTitle
    }

    private var displayArtist: String {
        musicManager.artistName.isEmpty ? musicManager.sourceName : musicManager.artistName
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                artworkView

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(displayArtist.isEmpty ? "Music" : displayArtist)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .padding(.top, 7)

                Spacer(minLength: 12)

                Button(action: musicManager.openCurrentPlayerApp) {
                    EqualizerGlyph(
                        isActive: isVisible && musicManager.isPlaying,
                        color: .white.opacity(0.5)
                    )
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IslandControlButtonStyle())
                .padding(.top, 5)
            }

            progressView

            HStack(spacing: 44) {
                Button {
                    Task { await musicManager.previousTrack() }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 27, weight: .bold))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.white)
                }
                .buttonStyle(IslandControlButtonStyle())
                .disabled(isLivestream)
                .opacity(isLivestream ? 0.4 : 1.0)

                Button(action: togglePlay) {
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .frame(width: 42, height: 40)
                        .foregroundStyle(.white)
                        .scaleEffect(playPauseBounce ? 1.08 : 1.0)
                        .animation(.interactiveSpring(duration: 0.22, extraBounce: 0.22), value: playPauseBounce)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(IslandControlButtonStyle(pressedScale: 0.9))

                Button {
                    Task { await musicManager.nextTrack() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 27, weight: .bold))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.white)
                }
                .buttonStyle(IslandControlButtonStyle())
                .disabled(isLivestream)
                .opacity(isLivestream ? 0.4 : 1.0)
            }
        }
        .padding(.horizontal, 19)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 405, height: 168)
        .background {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    musicManager.waveformColor.opacity(0.44),
                                    Color(red: 0.12, green: 0.32, blue: 0.68).opacity(0.48)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.2), radius: 22, y: 13)
    }

    private var artworkView: some View {
        ZStack {
            if let artwork = musicManager.artworkImage {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 7, y: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: musicManager.artworkImage)
    }

    @ViewBuilder
    private var progressView: some View {
        if isLivestream {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)

                Text("Livestream")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()
            }
            .frame(height: 24)
        } else {
            HStack(spacing: 9) {
                Text(formatPlaybackTime(musicManager.playbackPosition / 1000))
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.74))
                    .frame(width: 32, alignment: .leading)

                LockScreenSeekBar(
                    progress: progress,
                    onPreviewSeek: { musicManager.previewSeek(toProgress: $0) },
                    onSeek: { musicManager.seek(toProgress: $0) }
                )
                .frame(height: 20)

                Text(formatRemainingTime())
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.74))
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    private func togglePlay() {
        playPauseBounce = true

        Task {
            await musicManager.togglePlay()

            try? await Task.sleep(nanoseconds: 180_000_000)
            await MainActor.run {
                playPauseBounce = false
            }
        }
    }

    private func formatPlaybackTime(_ totalSeconds: TimeInterval) -> String {
        let seconds = max(0, Int(totalSeconds.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatRemainingTime() -> String {
        let remainingSeconds = max(0, (musicManager.durationMs - musicManager.playbackPosition) / 1000)
        return "-\(formatPlaybackTime(remainingSeconds))"
    }
}

private struct LockScreenSeekBar: View {
    let progress: CGFloat
    let onPreviewSeek: (CGFloat) -> Void
    let onSeek: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .frame(height: 6)

                Capsule()
                    .fill(Color.white.opacity(0.94))
                    .frame(width: max(7, geo.size.width * progress), height: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onPreviewSeek(normalizedProgress(value.location.x, width: geo.size.width))
                    }
                    .onEnded { value in
                        onSeek(normalizedProgress(value.location.x, width: geo.size.width))
                    }
            )
        }
    }

    private func normalizedProgress(_ xPosition: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return progress }
        return min(max(xPosition / width, 0), 1)
    }
}
