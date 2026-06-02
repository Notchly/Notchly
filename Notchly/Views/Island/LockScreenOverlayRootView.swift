//
//  LockScreenOverlayRootView.swift
//  Notchly
//
//  Created by user on 01.04.2026.
//

import SwiftUI

struct LockScreenOverlayRootView: View {
    @ObservedObject var model: LockScreenOverlayModel
    @ObservedObject var settingsManager: SettingsManager

    let musicManager: MusicManager
    let screenSize: CGSize
    let lockScreenPlayerYPosition: CGFloat
    let initialClosedHeight: CGFloat

    @State private var displayedState: LockScreenOverlayState = .locked
    @State private var isUnlocking = false
    @State private var renderLockScreenPlayer = true
    @State private var showLockScreenPlayer = true
    @State private var showOpenedLock = false
    @State private var openLockTask: DispatchWorkItem?
    @State private var completeTask: DispatchWorkItem?
    @State private var removePlayerTask: DispatchWorkItem?
    @State private var lastHandledState: LockScreenOverlayState?
    @State private var currentScreen: NSScreen?
    @State private var resolvedClosedHeight: CGFloat = IslandHeightResolver.fallbackHeight
    @State private var isArtworkExpanded = false

    init(
        model: LockScreenOverlayModel,
        settingsManager: SettingsManager,
        musicManager: MusicManager,
        screenSize: CGSize,
        lockScreenPlayerYPosition: CGFloat,
        initialClosedHeight: CGFloat
    ) {
        self.model = model
        self.settingsManager = settingsManager
        self.musicManager = musicManager
        self.screenSize = screenSize
        self.lockScreenPlayerYPosition = lockScreenPlayerYPosition
        self.initialClosedHeight = initialClosedHeight

        let initialState = model.state
        _displayedState = State(initialValue: initialState)
        _renderLockScreenPlayer = State(initialValue: initialState == .locked)
        _showLockScreenPlayer = State(initialValue: initialState == .locked)
        _lastHandledState = State(initialValue: initialState)
        _resolvedClosedHeight = State(initialValue: initialClosedHeight)
    }
    
    private func updateClosedHeight(for screen: NSScreen?) {
        let nextHeight = IslandHeightResolver.closedHeight(for: screen)
        guard resolvedClosedHeight != nextHeight else { return }
        resolvedClosedHeight = nextHeight
    }

    private let unlockAnimationDuration: TimeInterval = 0.18
    private let playerHideAnimationDuration: TimeInterval = 0.18

    private var isLockScreenPlayerVisible: Bool {
        displayedState == .locked && showLockScreenPlayer
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .allowsHitTesting(false)

            if renderLockScreenPlayer && settingsManager.showMusic && musicManager.hasNowPlayingContent {
                LockScreenMusicPlayerView(
                    musicManager: musicManager,
                    isVisible: isLockScreenPlayerVisible,
                    isArtworkExpanded: isArtworkExpanded,
                    onExpandArtwork: {
                        guard musicManager.artworkImage != nil else { return }

                        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                            isArtworkExpanded = true
                        }
                    },
                    onCollapseArtwork: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                            isArtworkExpanded = false
                        }
                    }
                )
                .position(x: screenSize.width / 2, y: lockScreenPlayerYPosition)
                .opacity(isLockScreenPlayerVisible ? 1 : 0)
                .scaleEffect(isLockScreenPlayerVisible ? 1 : 0.99)
                .offset(y: isLockScreenPlayerVisible ? 0 : 26)
                .allowsHitTesting(isLockScreenPlayerVisible)
                .zIndex(1)
            }

            LockScreenIslandView(
                islandWidth: CGFloat(settingsManager.islandWidth),
                height: resolvedClosedHeight,
                isUnlocking: isUnlocking,
                showOpenedLock: showOpenedLock
            )
            .position(x: screenSize.width / 2, y: resolvedClosedHeight / 2)
            .opacity(displayedState == .locked ? 1 : 0)
            .allowsHitTesting(false)
            .zIndex(displayedState == .locked ? 3 : 1)

        }
        .frame(width: screenSize.width, height: screenSize.height)
        .ignoresSafeArea(.all)
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
                isArtworkExpanded = false
            }
        }
        .onChange(of: musicManager.hasNowPlayingContent) { _, hasNowPlayingContent in
            if !hasNowPlayingContent {
                isArtworkExpanded = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in
            updateClosedHeight(for: currentScreen)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)) { _ in
            hideLockScreenPlayerForUnlock()
            updateClosedHeight(for: currentScreen)
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: NSNotification.Name("com.apple.screenIsUnlocked"))) { _ in
            hideLockScreenPlayerForUnlock()
        }
        .onDisappear {
            cancelPendingTasks()
        }
        .background(
            WindowScreenReader { screen in
                guard currentScreen !== screen else {
                    updateClosedHeight(for: screen)
                    return
                }

                currentScreen = screen
                updateClosedHeight(for: screen)
            }
        )
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
            isArtworkExpanded = false

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
    }

    @MainActor
    private func hideLockScreenPlayerForUnlock() {
        guard showLockScreenPlayer || renderLockScreenPlayer else { return }
        removePlayerTask?.cancel()

        if showLockScreenPlayer {
            withAnimation(.easeInOut(duration: playerHideAnimationDuration)) {
                isArtworkExpanded = false
                showLockScreenPlayer = false
            }
        } else {
            isArtworkExpanded = false
        }

        let newRemovePlayerTask = DispatchWorkItem {
            guard model.state == .music else { return }
            renderLockScreenPlayer = false
            removePlayerTask = nil
        }

        removePlayerTask = newRemovePlayerTask
        DispatchQueue.main.asyncAfter(deadline: .now() + playerHideAnimationDuration + 0.02, execute: newRemovePlayerTask)
    }

}
