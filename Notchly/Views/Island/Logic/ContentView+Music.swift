//
//  ContentView+Music.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI

extension ContentView {
    var musicContainer: some View {
        let isWaveformActive = animationsEnabled && musicManager.isPlaying
        let clippedWidth = max(0, layout.islandSize.width + layout.cornerRadius * 2)
        
        return IslandContainerView(
            size: layout.islandSize,
            cornerRadius: layout.cornerRadius,
            spacing: layout.spacing,
            shadowOpacity: status == .opened || status == .popping ? 0.2 : 0
        ) {
            if status == .closed || status == .popping || (status == .focusCollapse && focusCollapseShowsMusic) {
                CompactMusicView(
                    artwork: musicManager.artworkImage,
                    waveformColor: musicManager.waveformColor,
                    isPlaying: isWaveformActive,
                    size: layout.closedSize,
                    hoverOffsetY: hoverOffsetY,
                    skipIndicator: skipIndicator
                )
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(1)
            }

            if status == .musicPreview {
                PreviewMusicView(
                    artwork: musicManager.artworkImage,
                    combinedPreviewText: combinedPreviewText,
                    waveformColor: musicManager.waveformColor,
                    isPlaying: isWaveformActive,
                    size: layout.musicPreviewSize,
                    skipIndicator: skipIndicator
                )
                .offset(y: 10)
                .transition(
                    .scale(scale: 0.94)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: -10))
                )
                .zIndex(2)
            }
            
           

            if status == .focusPreview || (status == .focusCollapse && !focusCollapseShowsMusic) {
                FocusMusicStatusView(
                    isActive: focusStatusIsActive,
                    animationID: focusAnimationID,
                    size: layout.focusPreviewSize
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                .zIndex(4)
            }

            if status == .opened {
                ExpandedMusicView(
                    artwork: musicManager.artworkImage,
                    artworkTransitionKey: artworkTransitionKey,
                    title: musicManager.trackTitle,
                    artist: musicManager.artistName,
                    sourceName: musicManager.sourceName,
                    isPlaying: musicManager.isPlaying,
                    isShuffleEnabled: musicManager.isShuffleEnabled,
                    isShuffleControlAvailable: musicManager.isShuffleControlAvailable,
                    isLivestream: isLivestream,
                    waveformColor: musicManager.waveformColor,
                    playbackPositionText: formatPlaybackTime(musicManager.playbackPosition / 1000),
                    durationText: formatPlaybackTime(musicManager.durationMs / 1000),
                    progress: musicProgress,
                    outputVolume: musicManager.outputVolume,
                    isOutputMuted: musicManager.isOutputMuted,
                    isVolumeControlExpanded: showMusicVolumeControl,
                    size: layout.musicOpenedSize,
                    playPauseBounce: playPauseBounce,
                    onPreviewSeek: { progress in
                        musicManager.previewSeek(toProgress: progress)
                    },
                    onSeek: { progress in
                        musicManager.seek(toProgress: progress)
                    },
                    onVolumeChange: { volume in
                        musicManager.setOutputVolume(volume)
                    },
                    onToggleMute: {
                        musicManager.toggleOutputMute()
                    },
                    onToggleVolumeControl: {
                        withAnimation(animation) {
                            showMusicVolumeControl.toggle()
                        }
                    },
                    onToggleShuffle: {
                        musicManager.toggleShuffle(
                            allowSpotifyAppleScript: settingsManager.enableSpotifyAppleScriptControl,
                            allowAppleMusicAppleScript: settingsManager.enableAppleMusicAppleScriptControl
                        )
                    },
                    onPrevious: {
                        Task { await musicManager.previousTrack() }
                    },
                    onTogglePlay: {
                        animatePlayPauseButton()
                        Task { await musicManager.togglePlay() }
                    },
                    onNext: {
                        Task { await musicManager.nextTrack() }
                    },
                    onOpenSourceApp: {
                        musicManager.openCurrentPlayerApp()
                    }
                )
                .offset(y: 20)
                .transition(
                    .scale(scale: 0.9)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: -20))
                )
                .zIndex(3)
            }
        }
        .frame(width: clippedWidth, height: layout.islandSize.height)
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .overlay(
            ZStack {
                if status == .closed || status == .musicPreview {
                    IslandClickCatcher {
                        guard settingsManager.showMusic else { return }

                        autoExpandMusicTask?.cancel()

                        withAnimation(animation) {
                            status = .opened
                        }

                        scheduleAutoClose(after: 2.0)
                    }
                }

                if status != .opened {
                    ScrollSwipeCatcher { deltaX, deltaY in
                        handleMusicScroll(deltaX: deltaX, deltaY: deltaY)
                    }
                }
            }
        )
    }

    func handleMusicScroll(deltaX: CGFloat, deltaY: CGFloat) {
        guard settingsManager.showMusic else { return }
        guard status != .focusPreview else { return }
        guard status != .focusCollapse else { return }

        let horizontalTriggerThreshold: CGFloat = 14
        let verticalTriggerThreshold: CGFloat = 8
        let resetThreshold: CGFloat = 2

        if abs(deltaX) <= resetThreshold && abs(deltaY) <= resetThreshold {
            musicScrollGestureState = 0
            return
        }

        if abs(deltaX) > abs(deltaY) {
            if deltaX < -horizontalTriggerThreshold, musicScrollGestureState == 0 {
                musicScrollGestureState = 1
                autoExpandMusicTask?.cancel()
                performHapticFeedback()
                showSkipIndicator("forward.fill")

                Task { await musicManager.nextTrack() }
                return
            }

            if deltaX > horizontalTriggerThreshold, musicScrollGestureState == 0 {
                musicScrollGestureState = -1
                autoExpandMusicTask?.cancel()
                performHapticFeedback()
                showSkipIndicator("backward.fill")

                Task { await musicManager.previousTrack() }
                return
            }

            return
        }

        if abs(deltaY) > abs(deltaX) {
            if deltaY > verticalTriggerThreshold, status != .opened, musicScrollGestureState == 0 {
                musicScrollGestureState = 2
                autoExpandMusicTask?.cancel()
                performHapticFeedback()

                withAnimation(animation) {
                    status = .opened
                }

                scheduleAutoClose(after: 2.0)
                return
            }

            if deltaY < -verticalTriggerThreshold, status == .opened, musicScrollGestureState == 0 {
                musicScrollGestureState = -2
                autoExpandMusicTask?.cancel()
                performHapticFeedback()

                withAnimation(animation) {
                    status = .closed
                }
                return
            }
        }
    }

    func handleMusicAutoExpand(isPlaying: Bool) {
        guard dynamicManager.currentModule == .music else { return }
        guard isPlaying else { return }
        guard settingsManager.showMusic else { return }

        let key = currentMusicAutoOpenKey
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if lastMusicAutoOpenKey == key && (status == .musicPreview || status == .opened) {
            return
        }

        lastMusicAutoOpenKey = key
        autoExpandMusicTask?.cancel()

        if status == .opened {
            return
        }

        previewAutoCloseKey = key

        withAnimation(animation) {
            status = .musicPreview
        }

        let scheduledKey = key
        let previewDuration = settingsManager.musicPreviewDuration

        autoExpandMusicTask = Task {
            try? await Task.sleep(for: .seconds(previewDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard dynamicManager.currentModule == .music else { return }
                guard status == .musicPreview else { return }
                guard previewAutoCloseKey == scheduledKey else { return }

                withAnimation(animation) {
                    status = .closed
                }
            }
        }
    }
}

private struct FocusMusicStatusView: View {
    let isActive: Bool
    let animationID: Int
    let size: CGSize

    private var accentColor: Color {
        isActive ? Color(red: 0.62, green: 0.76, blue: 1.0) : .white.opacity(0.76)
    }

    private var statusText: String {
        isActive ? "On" : "Off"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accentColor)
                .symbolEffect(.bounce, value: animationID)
            .frame(width: 24, height: 24)

            Spacer()

            Text(statusText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(width: size.width, height: size.height)
    }
}
