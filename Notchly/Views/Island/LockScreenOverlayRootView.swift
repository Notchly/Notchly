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
    let initialClosedHeight: CGFloat

    @State private var displayedState: LockScreenOverlayState = .locked
    @State private var isUnlocking = false
    @State private var renderLockScreenPlayer = true
    @State private var showLockScreenPlayer = true
    @State private var showOpenedLock = false
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
        expandedArtworkSize: CGFloat,
        initialClosedHeight: CGFloat
    ) {
        self.model = model
        self.settingsManager = settingsManager
        self.musicManager = musicManager
        self.wallpaperManager = wallpaperManager
        self.wallpaperScreen = wallpaperScreen
        self.screenSize = screenSize
        self.lockScreenPlayerYPosition = lockScreenPlayerYPosition
        self.expandedArtworkSize = expandedArtworkSize
        self.initialClosedHeight = initialClosedHeight

        let initialState = model.state
        _displayedState = State(initialValue: initialState)
        _renderLockScreenPlayer = State(initialValue: initialState == .locked)
        _showLockScreenPlayer = State(initialValue: initialState == .locked)
        _lastHandledState = State(initialValue: initialState)
    }

    private let unlockAnimationDuration: TimeInterval = 0.18
    private let playerHideAnimationDuration: TimeInterval = 0.18
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

            LockScreenIslandView(
                islandWidth: CGFloat(settingsManager.islandWidth),
                height: initialClosedHeight,
                isUnlocking: isUnlocking,
                showOpenedLock: showOpenedLock
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(displayedState == .locked ? 1 : 0)
            .allowsHitTesting(false)
            .zIndex(displayedState == .locked ? 3 : 1)

        }
        .frame(width: screenSize.width, height: screenSize.height)
        .animation(.easeOut(duration: 0.16), value: displayedState)
        .animation(.easeInOut(duration: playerHideAnimationDuration), value: showLockScreenPlayer)
        .onAppear {
            displayedState = model.state
            renderLockScreenPlayer = model.state == .locked
            showLockScreenPlayer = model.state == .locked
            lastHandledState = model.state
        }
        .onChange(of: model.state) { _, newValue in
            handleStateChange(newValue)
        }
        .onChange(of: musicManager.artworkImage) { _, artworkImage in
            if artworkImage == nil {
                artworkTransitionID = UUID()
                model.isArtworkExpanded = false
                wallpaperManager.restore()
            }
        }
        .onChange(of: musicManager.wallpaperArtworkImage) { _, artworkImage in
            guard model.isArtworkExpanded else { return }

            if artworkImage == nil {
                artworkTransitionID = UUID()
                model.isArtworkExpanded = false
                wallpaperManager.restore()
            } else {
                applyArtworkWallpaper()
            }
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
            withAnimation(.easeOut(duration: 0.12)) {
                isUnlocking = false
                renderLockScreenPlayer = true
                showLockScreenPlayer = true
                showOpenedLock = false
                displayedState = .locked
            }

        case .music:
            model.isArtworkExpanded = false
            wallpaperManager.restore()

            guard displayedState == .locked else {
                showLockScreenPlayer = false

                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    displayedState = .music
                }
                return
            }

            displayedState = .locked

            hideLockScreenPlayerForUnlock()

            withAnimation(.easeInOut(duration: 0.12)) {
                isUnlocking = true
            }

            let newOpenLockTask = DispatchWorkItem {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
                    showOpenedLock = true
                }

                if settingsManager.enableLockSound {
                    UnlockSoundPlayer.shared.play()
                }
            }

            let newCompleteTask = DispatchWorkItem {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    displayedState = .music
                }

                isUnlocking = false
                showOpenedLock = false
            }

            openLockTask = newOpenLockTask
            completeTask = newCompleteTask

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: newOpenLockTask)
            DispatchQueue.main.asyncAfter(deadline: .now() + unlockAnimationDuration, execute: newCompleteTask)
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

    private func applyArtworkWallpaper(onReadyToApply: @escaping @MainActor () -> Void = {}) {
        guard let artwork = musicManager.wallpaperArtworkImage ?? musicManager.artworkImage else { return }
        wallpaperManager.apply(
            artwork: artwork,
            on: wallpaperScreen,
            onReadyToApply: onReadyToApply
        )
    }

    @MainActor
    private func expandArtwork() {
        guard musicManager.wallpaperArtworkImage != nil || musicManager.artworkImage != nil else { return }

        let transitionID = UUID()
        artworkTransitionID = transitionID
        applyArtworkWallpaper {
            guard artworkTransitionID == transitionID,
                  displayedState == .locked else { return }

            withAnimation(.smooth(duration: 0.30, extraBounce: 0)) {
                model.isArtworkExpanded = true
            }
        }
    }

    @MainActor
    private func collapseArtwork() {
        guard model.isArtworkExpanded else { return }

        artworkTransitionID = UUID()
        withAnimation(.smooth(duration: 0.30, extraBounce: 0)) {
            model.isArtworkExpanded = false
        }

        wallpaperManager.restoreAnimated()
    }
}
