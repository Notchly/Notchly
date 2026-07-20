//
//  LockScreenMusicPlayerView.swift
//  Notchly
//
//  Created by n0xbyte on 14.05.2026.
//

import SwiftUI
import AppKit

struct LockScreenMusicPlayerView: View {
    @ObservedObject var musicManager: MusicManager
    @ObservedObject var settingsManager: SettingsManager
    let isVisible: Bool
    let isArtworkExpanded: Bool
    let expandedArtworkSize: CGFloat
    let onExpandArtwork: () -> Void
    let onCollapseArtwork: () -> Void

    @State private var skipIndicator: String?
    @State private var skipIndicatorTask: Task<Void, Never>?
    @State private var artworkTransitionDirection: LockScreenArtworkTransitionDirection = .forward

    private let playerWidth: CGFloat = 339 * 1.10
    private let playerHeight: CGFloat = 154 * 1.10

    private var progress: CGFloat {
        guard musicManager.durationMs > 0 else { return 0 }
        return CGFloat(min(max(musicManager.playbackPosition / musicManager.durationMs, 0), 1))
    }

    private var playbackState: PlaybackState {
        musicManager.isResolvingNowPlaying ? .loading : (musicManager.isPlaying ? .playing : .paused)
    }

    private var isLivestream: Bool {
        musicManager.durationMs <= 0
    }

    private var lockScreenTrack: LockScreenTrack {
        LockScreenTrack(
            id: stableTrackID,
            title: displayTitle,
            artist: displayArtist.isEmpty ? "Music" : displayArtist,
            artwork: musicManager.wallpaperArtworkImage ?? musicManager.artworkImage
        )
    }

    private var stableTrackID: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(stableTrackIDFragment)") ?? UUID()
    }

    private var stableTrackIDFragment: String {
        let hash = abs(artworkTransitionKey.hashValue)
        return String(format: "%012llx", UInt64(hash) & 0xFFFFFFFFFFFF)
    }

    private var audioActivityLevels: [CGFloat] {
        guard isVisible && musicManager.isPlaying else { return [5, 8, 6, 10] }

        let volume = CGFloat(min(max(musicManager.outputVolume, 0), 1))
        return [
            6 + volume * 5,
            10 + volume * 7,
            7 + volume * 6,
            12 + volume * 6
        ]
    }

    private var displayTitle: String {
        musicManager.trackTitle.isEmpty ? "Now Playing" : musicManager.trackTitle
    }

    private var displayArtist: String {
        musicManager.artistName.isEmpty ? musicManager.sourceName : musicManager.artistName
    }

    private var artworkTransitionKey: String {
        "\(musicManager.trackTitle)|\(musicManager.artistName)|\(musicManager.albumTitle)"
    }

    var body: some View {
        LockScreenMusicView(
            track: lockScreenTrack,
            playbackState: playbackState,
            progress: Double(progress),
            currentTime: musicManager.playbackPosition / 1000,
            duration: musicManager.durationMs / 1000,
            isLivestream: isLivestream,
            isShuffleEnabled: musicManager.isShuffleEnabled,
            isShuffleAvailable: musicManager.isShuffleControlAvailable,
            outputVolume: musicManager.outputVolume,
            isOutputMuted: musicManager.isOutputMuted,
            audioActivityLevels: audioActivityLevels,
            skipIndicator: skipIndicator,
            isArtworkExpanded: isArtworkExpanded,
            expandedArtworkSize: expandedArtworkSize,
            artworkTransitionDirection: artworkTransitionDirection,
            onArtworkTap: {
                guard musicManager.artworkImage != nil else { return }
                onExpandArtwork()
            },
            onCollapseArtwork: onCollapseArtwork,
            onTogglePlayback: musicManager.togglePlay,
            onPrevious: previousTrack,
            onNext: nextTrack,
            onToggleShuffle: toggleShuffle,
            onToggleOutputMute: musicManager.toggleOutputMute,
            onPreviewSeek: { musicManager.previewSeek(toProgress: $0) },
            onSeek: { musicManager.seek(toProgress: $0) }
        )
        .frame(width: playerWidth, height: playerHeight)
        .onDisappear {
            skipIndicatorTask?.cancel()
            skipIndicatorTask = nil
            skipIndicator = nil
        }
    }

    private func previousTrack() {
        artworkTransitionDirection = .backward
        animateSkip(symbol: "backward.fill")
        musicManager.previousTrack()
    }

    private func nextTrack() {
        artworkTransitionDirection = .forward
        animateSkip(symbol: "forward.fill")
        musicManager.nextTrack()
    }

    private func toggleShuffle() {
        musicManager.toggleShuffle(
            allowSpotifyAppleScript: settingsManager.enableSpotifyAppleScriptControl,
            allowAppleMusicAppleScript: settingsManager.enableAppleMusicAppleScriptControl
        )
    }

    private func animateSkip(symbol: String) {
        skipIndicatorTask?.cancel()

        withAnimation(.interactiveSpring(duration: 0.14, extraBounce: 0.12)) {
            skipIndicator = symbol
        }

        skipIndicatorTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.12)) {
                skipIndicator = nil
            }
            skipIndicatorTask = nil
        }
    }
}
