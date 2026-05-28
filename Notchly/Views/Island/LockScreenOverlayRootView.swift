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
    @ObservedObject var focusManager: FocusManager

    let batteryManager: BatteryManager
    let dynamicManager: DynamicManager
    let musicManager: MusicManager
    let brightnessManager: BrightnessManager
    let screenSize: CGSize

    @State private var displayedState: LockScreenOverlayState = .locked
    @State private var isUnlocking = false
    @State private var showLockScreenPlayer = true
    @State private var showOpenedLock = false
    @State private var openLockTask: DispatchWorkItem?
    @State private var completeTask: DispatchWorkItem?
    @State private var lastHandledState: LockScreenOverlayState?
    @State private var currentScreen: NSScreen?
    @State private var resolvedClosedHeight: CGFloat = IslandHeightResolver.fallbackHeight
    @State private var isArtworkExpanded = false

    init(
        model: LockScreenOverlayModel,
        settingsManager: SettingsManager,
        focusManager: FocusManager,
        batteryManager: BatteryManager,
        dynamicManager: DynamicManager,
        musicManager: MusicManager,
        brightnessManager: BrightnessManager,
        screenSize: CGSize
    ) {
        self.model = model
        self.settingsManager = settingsManager
        self.focusManager = focusManager
        self.batteryManager = batteryManager
        self.dynamicManager = dynamicManager
        self.musicManager = musicManager
        self.brightnessManager = brightnessManager
        self.screenSize = screenSize

        let initialState = model.state
        _displayedState = State(initialValue: initialState)
        _showLockScreenPlayer = State(initialValue: initialState == .locked)
        _lastHandledState = State(initialValue: initialState)
    }
    
    private func updateClosedHeight(for screen: NSScreen?) {
        let nextHeight = IslandHeightResolver.closedHeight(for: screen)
        guard resolvedClosedHeight != nextHeight else { return }
        resolvedClosedHeight = nextHeight
    }

    private let unlockAnimationDuration: TimeInterval = 0.18

    private var lockScreenPlayerYPosition: CGFloat {
        min(max(screenSize.height * 0.68, 500), screenSize.height - 130)
    }

    private var isRegularIslandVisible: Bool {
        displayedState == .music
    }

    private var isLockScreenPlayerVisible: Bool {
        displayedState == .locked && showLockScreenPlayer
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            ContentView(
                batteryManager: batteryManager,
                settingsManager: settingsManager,
                dynamicManager: dynamicManager,
                musicManager: musicManager,
                focusManager: focusManager,
                brightnessManager: brightnessManager,
                animationsEnabled: isRegularIslandVisible
            )
            .padding(.top, 0)
            .opacity(isRegularIslandVisible ? 1 : 0)
            .allowsHitTesting(isRegularIslandVisible)
            .accessibilityHidden(!isRegularIslandVisible)
            .zIndex(isRegularIslandVisible ? 2 : -1)

            if settingsManager.showMusic && musicManager.hasNowPlayingContent {
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
                .scaleEffect(isLockScreenPlayerVisible ? 1 : 0.96)
                .offset(y: isLockScreenPlayerVisible ? 0 : 18)
                .allowsHitTesting(isLockScreenPlayerVisible)
                .zIndex(1)
            }

            LockScreenIslandView(
                height: resolvedClosedHeight,
                isUnlocking: isUnlocking,
                showOpenedLock: showOpenedLock
            )
            .padding(.top, 0)
            .opacity(displayedState == .locked ? 1 : 0)
            .allowsHitTesting(false)
            .zIndex(displayedState == .locked ? 3 : 1)

        }
        .frame(width: screenSize.width, height: screenSize.height)
        .animation(.easeOut(duration: 0.16), value: displayedState)
        .animation(.easeOut(duration: 0.12), value: showLockScreenPlayer)
        .onAppear {
            displayedState = model.state
            showLockScreenPlayer = model.state == .locked
            lastHandledState = model.state
            updateClosedHeight(for: currentScreen)
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
    }

    @MainActor
    private func hideLockScreenPlayerForUnlock() {
        guard showLockScreenPlayer else { return }

        withAnimation(.easeOut(duration: 0.12)) {
            isArtworkExpanded = false
            showLockScreenPlayer = false
        }
    }

}
