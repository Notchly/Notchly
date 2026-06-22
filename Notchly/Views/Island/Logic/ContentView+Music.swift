//
//  ContentView+Music.swift
//  Notchly
//
//  Created by n0xbyte on 25.03.2026.
//

import SwiftUI

extension ContentView {
    var musicContainer: some View {
        let isWaveformActive = animationsEnabled && musicManager.isPlaying
        let clippedWidth = max(0, layout.islandSize.width + layout.cornerRadius * 2)
        let agentEvent = displayedAgentEvent ?? agentEventManager.currentEvent
        let hasPendingAgentEvent =
            agentEvent != nil &&
            (showsAgentOverMusic || isAgentMusicTransitionActive)
        let showsAgentActivity =
            hasPendingAgentEvent &&
            isAgentMusicTransitionActive &&
            status == .agentPreview
        
        return IslandContainerView(
            size: layout.islandSize,
            cornerRadius: layout.cornerRadius,
            spacing: layout.spacing,
            shadowOpacity: status == .opened || status == .popping ? 0.2 : 0,
            showsTopCornerCutouts: !hasPendingAgentEvent
        ) {
            if !hidesMusicContentDuringAgentReturn && !hasPendingAgentEvent && (status == .closed ||
                status == .popping ||
                (status == .focusCollapse && focusCollapseShowsMusic && !hidesFocusStatusContentDuringReturn) ||
                (status == .brightnessCollapse && brightnessCollapseShowsMusic && !hidesBrightnessStatusContentDuringReturn) ||
                (status == .volumeCollapse && volumeCollapseShowsMusic && !hidesVolumeStatusContentDuringReturn)) {
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

            if !hidesMusicContentDuringAgentReturn && !hasPendingAgentEvent && status == .musicPreview {
                PreviewMusicView(
                    artwork: musicManager.artworkImage,
                    combinedPreviewText: combinedPreviewText,
                    waveformColor: musicManager.waveformColor,
                    isPlaying: isWaveformActive,
                    size: layout.musicPreviewSize,
                    skipIndicator: skipIndicator
                )
                .offset(y: 10)
                .opacity(showsAgentActivity && showsAgentMusicContent ? 0 : 1)
                .scaleEffect(showsAgentActivity && showsAgentMusicContent ? 0.985 : 1)
                .animation(.smooth(duration: 0.3, extraBounce: 0), value: showsAgentMusicContent)
                .transition(.opacity.combined(with: .offset(y: 6)))
                .zIndex(2)
            }

            if showsAgentActivity {
                AgentActivityView(
                    event: agentEvent,
                    size: layout.musicPreviewSize
                )
                .offset(y: 10)
                .opacity(showsAgentMusicContent ? 1 : 0)
                .scaleEffect(showsAgentMusicContent ? 1 : 0.985)
                .animation(.smooth(duration: 0.3, extraBounce: 0), value: showsAgentMusicContent)
                .transition(
                    .scale(scale: 0.985)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: -4))
                )
                .zIndex(5)
            }

            if status == .focusPreview || (status == .focusCollapse && !focusCollapseShowsMusic && !hidesFocusStatusContentDuringReturn) {
                FocusMusicStatusView(
                    isActive: focusStatusIsActive,
                    hidesLabel: settingsManager.hideFocusLabel,
                    size: layout.focusPreviewSize
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                .zIndex(4)
            }

            if status == .brightnessPreview || (status == .brightnessCollapse && !brightnessCollapseShowsMusic && !hidesBrightnessStatusContentDuringReturn) {
                BrightnessStatusView(
                    brightness: brightnessManager.brightnessLevel,
                    lineWidth: CGFloat(settingsManager.brightnessLineWidth),
                    showsLine: settingsManager.showBrightnessLine,
                    showsPercent: settingsManager.showBrightnessPercent,
                    size: layout.brightnessPreviewSize
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                .zIndex(4)
            }

            if status == .volumePreview || (status == .volumeCollapse && !volumeCollapseShowsMusic && !hidesVolumeStatusContentDuringReturn) {
                VolumeStatusView(
                    volume: musicManager.outputVolume,
                    isMuted: musicManager.isOutputMuted,
                    lineWidth: CGFloat(settingsManager.soundLineWidth),
                    showsLine: settingsManager.showSoundLine,
                    showsPercent: settingsManager.showSoundPercent,
                    size: layout.volumePreviewSize
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
                .zIndex(4)
            }

            if !hidesMusicContentDuringAgentReturn && status == .opened {
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
                        musicManager.previousTrack()
                        scheduleMusicAutoCloseAfterInteraction()
                    },
                    onTogglePlay: {
                        animatePlayPauseButton()
                        musicManager.togglePlay()
                    },
                    onNext: {
                        musicManager.nextTrack()
                        scheduleMusicAutoCloseAfterInteraction()
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
        .animation(
            isAgentMusicTransitionActive ? .smooth(duration: 0.42, extraBounce: 0) : animation,
            value: layout.islandSize.width
        )
        .animation(
            isAgentMusicTransitionActive ? .smooth(duration: 0.42, extraBounce: 0) : animation,
            value: layout.islandSize.height
        )
        .animation(
            isAgentMusicTransitionActive ? .smooth(duration: 0.42, extraBounce: 0) : animation,
            value: layout.cornerRadius
        )
        .frame(width: clippedWidth, height: layout.islandSize.height)
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: layout.cornerRadius))
        .overlay(
            ZStack {
                if !hasPendingAgentEvent && (status == .closed || status == .musicPreview) {
                    IslandClickCatcher {
                        guard settingsManager.showMusic else { return }

                        autoExpandMusicTask?.cancel()

                        withAnimation(animation) {
                            status = .opened
                        }

                        scheduleAutoClose(after: 2.0)
                    }
                }

                if hasPendingAgentEvent {
                    IslandClickCatcher {
                        openAgentSourceApp(agentEvent)
                    }
                }

                if status != .opened && !hasPendingAgentEvent {
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
        guard status != .brightnessPreview else { return }
        guard status != .brightnessCollapse else { return }
        guard status != .volumePreview else { return }
        guard status != .volumeCollapse else { return }

        let horizontalTriggerThreshold: CGFloat = 14
        let verticalTriggerThreshold: CGFloat = 8
        let resetThreshold: CGFloat = 2
        let trackSwipeCooldown: TimeInterval = 0.75

        if abs(deltaX) <= resetThreshold && abs(deltaY) <= resetThreshold {
            musicScrollGestureState = 0
            return
        }

        if abs(deltaX) > abs(deltaY) {
            if deltaX < -horizontalTriggerThreshold, musicScrollGestureState == 0 {
                let now = Date.timeIntervalSinceReferenceDate
                guard now - lastMusicTrackSwipeTime >= trackSwipeCooldown else { return }

                musicScrollGestureState = 1
                lastMusicTrackSwipeTime = now
                autoExpandMusicTask?.cancel()
                performHapticFeedback()
                showSkipIndicator("forward.fill")

                musicManager.nextTrack()
                scheduleMusicAutoCloseAfterInteraction()
                return
            }

            if deltaX > horizontalTriggerThreshold, musicScrollGestureState == 0 {
                let now = Date.timeIntervalSinceReferenceDate
                guard now - lastMusicTrackSwipeTime >= trackSwipeCooldown else { return }

                musicScrollGestureState = -1
                lastMusicTrackSwipeTime = now
                autoExpandMusicTask?.cancel()
                performHapticFeedback()
                showSkipIndicator("backward.fill")

                musicManager.previousTrack()
                scheduleMusicAutoCloseAfterInteraction()
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
        guard !isAgentAlertBlockingOtherEvents else { return }
        guard dynamicManager.currentModule == .music || musicManager.hasNowPlayingContent else { return }
        guard isPlaying else { return }
        guard settingsManager.showMusic else { return }
        guard status == .closed || status == .musicPreview || status == .opened else { return }

        let key = currentMusicAutoOpenKey
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if stagedMusicAutoOpenKey == key && status == .closed {
            return
        }

        let shouldStageClosedMusicPreview =
            status == .closed &&
            (musicStartUsesIdleWidth || lastMusicAutoOpenKey.isEmpty || dynamicManager.currentModule != .music)

        if shouldStageClosedMusicPreview {
            stagedMusicAutoOpenKey = key
            autoExpandMusicTask?.cancel()

            autoExpandMusicTask = Task {
                try? await Task.sleep(for: .milliseconds(520))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard musicManager.isPlaying else { return }
                    guard musicManager.hasNowPlayingContent else { return }
                    guard status == .closed else { return }
                    guard stagedMusicAutoOpenKey == key else { return }

                    stagedMusicAutoOpenKey = ""
                    openMusicPreview(for: key)
                }
            }
            return
        }

        if lastMusicAutoOpenKey == key && (status == .musicPreview || status == .opened) {
            return
        }

        openMusicPreview(for: key)
    }

    func openMusicPreview(for key: String) {
        lastMusicAutoOpenKey = key
        stagedMusicAutoOpenKey = ""
        autoExpandMusicTask?.cancel()

        if status == .opened {
            scheduleAutoClose(after: 2.0)
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
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard dynamicManager.currentModule == .music || musicManager.hasNowPlayingContent else { return }
                guard status == .musicPreview else { return }
                guard previewAutoCloseKey == scheduledKey else { return }

                withAnimation(animation) {
                    status = .closed
                }
            }
        }
    }

    func handleMusicPlaybackChange(isPlaying: Bool) {
        guard settingsManager.showMusic else { return }

        if isPlaying {
            defer { lastMusicPauseDate = nil }

            guard let lastMusicPauseDate else {
                handleMusicAutoExpand(isPlaying: true)
                return
            }

            guard Date().timeIntervalSince(lastMusicPauseDate) >= 15 else { return }

            handleMusicAutoExpand(isPlaying: true)
            return
        }

        lastMusicPauseDate = Date()

        guard status == .musicPreview else { return }

        autoExpandMusicTask?.cancel()
        autoExpandMusicTask = nil
        previewAutoCloseKey = ""

        withAnimation(animation) {
            status = .closed
        }
    }

    func scheduleMusicAutoCloseAfterInteraction() {
        guard status == .opened || status == .musicPreview else { return }
        scheduleAutoClose(after: 2.0)
    }
}

private struct FocusMusicStatusView: View {
    let isActive: Bool
    let hidesLabel: Bool
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
                .symbolEffect(.bounce, value: isActive)
            .frame(width: 24, height: 24)

            Spacer()

            if !hidesLabel {
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: size.width, height: size.height)
    }
}

private struct BrightnessStatusView: View {
    let brightness: Double
    let lineWidth: CGFloat
    let showsLine: Bool
    let showsPercent: Bool
    let size: CGSize

    private var clampedBrightness: Double {
        min(max(brightness, 0), 1)
    }

    private var percentage: Int {
        Int((clampedBrightness * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: brightnessSymbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 24, height: 24)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if showsLine {
                    GeometryReader { geo in
                        let width = max(geo.size.width, 1)
                        let fillWidth = width * clampedBrightness

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 5)

                            Capsule()
                                .fill(Color.white.opacity(0.88))
                                .frame(width: fillWidth, height: 5)
                                .animation(.easeOut(duration: 0.12), value: clampedBrightness)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: lineWidth, height: 20)
                }

                if showsPercent {
                    Text("\(percentage)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: size.width, height: size.height)
    }

    private var brightnessSymbolName: String {
        switch percentage {
        case 0...25:
            return "sun.min.fill"
        case 26...75:
            return "sun.max"
        default:
            return "sun.max.fill"
        }
    }
}

private struct VolumeStatusView: View {
    let volume: Double
    let isMuted: Bool
    let lineWidth: CGFloat
    let showsLine: Bool
    let showsPercent: Bool
    let size: CGSize

    private var clampedVolume: Double {
        isMuted ? 0 : min(max(volume, 0), 1)
    }

    private var percentage: Int {
        Int((clampedVolume * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: volumeSymbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 24, height: 24)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if showsLine {
                    GeometryReader { geo in
                        let width = max(geo.size.width, 1)
                        let fillWidth = width * clampedVolume

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 5)

                            Capsule()
                                .fill(Color.white.opacity(0.88))
                                .frame(width: fillWidth, height: 5)
                                .animation(.easeOut(duration: 0.12), value: clampedVolume)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: lineWidth, height: 20)
                }

                if showsPercent {
                    Text("\(percentage)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: size.width, height: size.height)
    }

    private var volumeSymbolName: String {
        switch percentage {
        case 0:
            return "speaker.slash.fill"
        case 1...33:
            return "speaker.wave.1.fill"
        case 34...66:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }
}
