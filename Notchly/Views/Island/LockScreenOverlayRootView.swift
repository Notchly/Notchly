//
//  LockScreenOverlayRootView.swift
//  Notchly
//
//  Created by n0xbyte on 01.04.2026.
//

import SwiftUI

struct LockScreenOverlayRootView: View {
    @ObservedObject var model: LockScreenOverlayModel
    @ObservedObject var settingsManager: SettingsManager

    let musicManager: MusicManager
    let wallpaperManager: LockScreenWallpaperManager
    let wallpaperScreen: NSScreen
    let screenSize: CGSize
    let lockScreenPlayerYPosition: CGFloat
    let expandedArtworkSize: CGFloat

    @State private var displayedState: LockScreenOverlayState = .locked
    @State private var renderLockScreenPlayer = true
    @State private var showLockScreenPlayer = true
    @State private var openLockTask: DispatchWorkItem?
    @State private var completeTask: DispatchWorkItem?
    @State private var removePlayerTask: DispatchWorkItem?
    @State private var artworkTransitionID = UUID()
    @State private var lastHandledState: LockScreenOverlayState?

    init(
        model: LockScreenOverlayModel,
        settingsManager: SettingsManager,
        musicManager: MusicManager,
        wallpaperManager: LockScreenWallpaperManager,
        wallpaperScreen: NSScreen,
        screenSize: CGSize,
        lockScreenPlayerYPosition: CGFloat,
        expandedArtworkSize: CGFloat
    ) {
        self.model = model
        self.settingsManager = settingsManager
        self.musicManager = musicManager
        self.wallpaperManager = wallpaperManager
        self.wallpaperScreen = wallpaperScreen
        self.screenSize = screenSize
        self.lockScreenPlayerYPosition = lockScreenPlayerYPosition
        self.expandedArtworkSize = expandedArtworkSize

        let initialState = model.state
        _displayedState = State(initialValue: initialState)
        _renderLockScreenPlayer = State(initialValue: initialState == .locked)
        _showLockScreenPlayer = State(initialValue: initialState == .locked)
        _lastHandledState = State(initialValue: initialState)
    }

    private let playerHideAnimationDuration: TimeInterval = 0.14
    private let expandedPlayerShift: CGFloat = 18
    private let playerScale: CGFloat = 1.10
    private let playerBaseHeight: CGFloat = 154

    private var isLockScreenPlayerVisible: Bool {
        displayedState == .locked && showLockScreenPlayer
    }

    private var displayedPlayerYPosition: CGFloat {
        let lowerPlayerOffset = playerBaseHeight * playerScale * 0.10
        let expandedCompositionOffset = model.isArtworkExpanded
            ? displayedArtworkSize * 0.10
            : 0
        return lockScreenPlayerYPosition + lowerPlayerOffset + expandedCompositionOffset +
            (model.isArtworkExpanded ? expandedPlayerShift : 0)
    }

    private var displayedArtworkSize: CGFloat {
        guard model.isArtworkExpanded else { return expandedArtworkSize }
        return (expandedArtworkSize + expandedPlayerShift) * 1.05
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .allowsHitTesting(false)

            if renderLockScreenPlayer && settingsManager.showMusic && musicManager.hasNowPlayingContent {
                LockScreenMusicPlayerView(
                    musicManager: musicManager,
                    settingsManager: settingsManager,
                    isVisible: isLockScreenPlayerVisible,
                    isArtworkExpanded: model.isArtworkExpanded,
                    expandedArtworkSize: displayedArtworkSize,
                    onExpandArtwork: expandArtwork,
                    onCollapseArtwork: collapseArtwork
                )
                .position(x: screenSize.width / 2, y: displayedPlayerYPosition)
                .opacity(isLockScreenPlayerVisible ? 1 : 0)
                .scaleEffect(isLockScreenPlayerVisible ? 1 : 0.99)
                .offset(y: isLockScreenPlayerVisible ? 0 : 26)
                .allowsHitTesting(isLockScreenPlayerVisible)
                .zIndex(1)
            }

        }
        .frame(width: screenSize.width, height: screenSize.height)
        .ignoresSafeArea(.all)
        .animation(.easeInOut(duration: playerHideAnimationDuration), value: showLockScreenPlayer)
        .onAppear {
            displayedState = model.state
            renderLockScreenPlayer = model.state == .locked
            showLockScreenPlayer = model.state == .locked
            lastHandledState = model.state
            restoreExpandedArtworkIfNeeded()
        }
        .onChange(of: model.state) { _, newValue in
            handleStateChange(newValue)
        }
        .onChange(of: musicManager.wallpaperArtworkRevision) { _, _ in
            handleWallpaperArtworkRevision()
        }
        .onChange(of: musicManager.hasNowPlayingContent) { _, hasNowPlayingContent in
            if !hasNowPlayingContent {
                artworkTransitionID = UUID()
                model.isArtworkExpanded = false
                wallpaperManager.restore()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)) { _ in
            hideLockScreenPlayerForUnlock()
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.screenIsUnlocked"))) { _ in
            hideLockScreenPlayerForUnlock()
        }
        .onDisappear {
            cancelPendingTasks()
            model.isArtworkExpanded = false
            wallpaperManager.restore()
        }
    }

    @MainActor
    private func handleStateChange(_ newValue: LockScreenOverlayState) {
        guard lastHandledState != newValue else { return }
        lastHandledState = newValue

        cancelPendingTasks()

        switch newValue {
        case .locked:
            withAnimation(.easeOut(duration: playerHideAnimationDuration)) {
                renderLockScreenPlayer = true
                showLockScreenPlayer = true
                displayedState = .locked
            }
            restoreExpandedArtworkIfNeeded()

        case .music:
            model.isArtworkExpanded = false
            wallpaperManager.restore()

            guard displayedState == .locked else {
                showLockScreenPlayer = false

                withAnimation(.smooth(
                    duration: LockScreenTransitionTiming.overlayFadeDuration,
                    extraBounce: 0
                )) {
                    displayedState = .music
                }
                return
            }

            displayedState = .locked

            hideLockScreenPlayerForUnlock()

            let newOpenLockTask = DispatchWorkItem {
                if settingsManager.enableLockSound {
                    UnlockSoundPlayer.shared.play()
                }
            }

            let newCompleteTask = DispatchWorkItem {
                withAnimation(.smooth(
                    duration: LockScreenTransitionTiming.overlayFadeDuration,
                    extraBounce: 0
                )) {
                    displayedState = .music
                }
            }

            openLockTask = newOpenLockTask
            completeTask = newCompleteTask

            DispatchQueue.main.asyncAfter(
                deadline: .now() + LockScreenTransitionTiming.unlockIconDelay,
                execute: newOpenLockTask
            )
            DispatchQueue.main.asyncAfter(
                deadline: .now() + LockScreenTransitionTiming.overlayFadeStartDelay,
                execute: newCompleteTask
            )
        }
    }

    @MainActor
    private func cancelPendingTasks() {
        openLockTask?.cancel()
        openLockTask = nil

        completeTask?.cancel()
        completeTask = nil

        removePlayerTask?.cancel()
        removePlayerTask = nil

        artworkTransitionID = UUID()
    }

    @MainActor
    private func hideLockScreenPlayerForUnlock() {
        guard showLockScreenPlayer || renderLockScreenPlayer else { return }
        removePlayerTask?.cancel()
        artworkTransitionID = UUID()

        if showLockScreenPlayer {
            withAnimation(.easeInOut(duration: playerHideAnimationDuration)) {
                model.isArtworkExpanded = false
                showLockScreenPlayer = false
            }
            wallpaperManager.restore()
        } else {
            model.isArtworkExpanded = false
            wallpaperManager.restore()
        }

        let newRemovePlayerTask = DispatchWorkItem {
            guard model.state == .music else { return }
            renderLockScreenPlayer = false
            removePlayerTask = nil
        }

        removePlayerTask = newRemovePlayerTask
        DispatchQueue.main.asyncAfter(deadline: .now() + playerHideAnimationDuration + 0.02, execute: newRemovePlayerTask)
    }

    private func applyArtworkWallpaper(
        artwork: NSImage,
        onReadyToApply: @escaping @MainActor () -> Void = {}
    ) {
        wallpaperManager.apply(
            artwork: artwork,
            on: wallpaperScreen,
            onReadyToApply: onReadyToApply
        )
    }

    @MainActor
    private func expandArtwork() {
        guard let artwork = musicManager.wallpaperArtworkImage ?? musicManager.artworkImage else { return }

        model.prefersExpandedArtwork = true
        applyExpandedArtwork(artwork)
    }

    @MainActor
    private func collapseArtwork() {
        guard model.isArtworkExpanded || model.prefersExpandedArtwork else { return }

        artworkTransitionID = UUID()
        model.prefersExpandedArtwork = false
        withAnimation(.smooth(duration: 0.30, extraBounce: 0)) {
            model.isArtworkExpanded = false
        }

        wallpaperManager.restoreAnimated()
    }

    @MainActor
    private func restoreExpandedArtworkIfNeeded() {
        guard model.prefersExpandedArtwork,
              model.state == .locked,
              musicManager.wallpaperArtworkIdentity == musicManager.currentTrackIdentity,
              let artwork = musicManager.wallpaperArtworkImage ?? musicManager.artworkImage else {
            return
        }

        applyExpandedArtwork(artwork)
    }

    @MainActor
    private func handleWallpaperArtworkRevision() {
        guard model.prefersExpandedArtwork,
              model.state == .locked else { return }

        guard !musicManager.wallpaperArtworkIdentity.isEmpty,
              musicManager.wallpaperArtworkIdentity == musicManager.currentTrackIdentity,
              let artwork = musicManager.wallpaperArtworkImage else {
            artworkTransitionID = UUID()
            withAnimation(.smooth(duration: 0.24, extraBounce: 0)) {
                model.isArtworkExpanded = false
            }
            wallpaperManager.restoreAnimated()
            return
        }

        applyExpandedArtwork(artwork)
    }

    @MainActor
    private func applyExpandedArtwork(_ artwork: NSImage) {
        let transitionID = UUID()
        artworkTransitionID = transitionID

        applyArtworkWallpaper(artwork: artwork) {
            guard artworkTransitionID == transitionID,
                  model.prefersExpandedArtwork,
                  model.state == .locked,
                  displayedState == .locked else { return }

            guard !model.isArtworkExpanded else { return }
            withAnimation(.smooth(duration: 0.30, extraBounce: 0)) {
                model.isArtworkExpanded = true
            }
        }
    }
}
