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

    let batteryManager: BatteryManager
    let dynamicManager: DynamicManager
    let musicManager: MusicManager
    let screenSize: CGSize

    @State private var displayedState: LockScreenOverlayState = .locked
    @State private var isUnlocking = false
    @State private var showOpenedLock = false
    @State private var openLockTask: DispatchWorkItem?
    @State private var completeTask: DispatchWorkItem?
    @State private var lastHandledState: LockScreenOverlayState?
    @State private var currentScreen: NSScreen?
    @State private var resolvedClosedHeight: CGFloat = IslandHeightResolver.fallbackHeight
    
    private func updateClosedHeight(for screen: NSScreen?) {
        resolvedClosedHeight = IslandHeightResolver.closedHeight(for: screen)
    }

    private let unlockAnimationDuration: TimeInterval = 0.18

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            if displayedState == .locked {
                LockScreenIslandView(
                    height: resolvedClosedHeight,
                    isUnlocking: isUnlocking,
                    showOpenedLock: showOpenedLock
                )
                .padding(.top, 0)
                .transition(.opacity)
            }

            if displayedState == .music {
                ContentView(
                    batteryManager: batteryManager,
                    settingsManager: settingsManager,
                    dynamicManager: dynamicManager,
                    musicManager: musicManager
                )
                .padding(.top, 0)
                .transition(.opacity)
            }
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .animation(.easeOut(duration: 0.16), value: displayedState)
        .onAppear {
            displayedState = model.state
            lastHandledState = model.state
            updateClosedHeight(for: currentScreen)
        }
        .onChange(of: model.state) { _, newValue in
            handleStateChange(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in
            updateClosedHeight(for: currentScreen)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification)) { _ in
            updateClosedHeight(for: currentScreen)
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
                showOpenedLock = false
                displayedState = .locked
            }

        case .music:
            guard displayedState == .locked else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    displayedState = .music
                }
                return
            }

            displayedState = .locked

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
}
