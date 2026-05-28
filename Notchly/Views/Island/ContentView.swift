//
//  ContentView.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var batteryManager: BatteryManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var dynamicManager: DynamicManager
    @ObservedObject var musicManager: MusicManager
    @ObservedObject var focusManager: FocusManager
    @ObservedObject var brightnessManager: BrightnessManager
    let animationsEnabled: Bool

    @State var status: IslandStatus = .closed
    @State var showChargingPop = false
    @State var isHovered = false
    @State var hasFinishedInitialAppear = false
    @State var autoExpandMusicTask: Task<Void, Never>?
    @State var focusStatusTask: Task<Void, Never>?
    @State var lastMusicAutoOpenKey: String = ""
    @State var previewAutoCloseKey: String = ""
    @State var focusReturnStatus: IslandStatus = .closed
    @State var focusCollapseShowsMusic = true
    @State var focusStatusIsActive = false
    @State var pendingFocusEventIsActive = false
    @State var pendingFocusEventTimestamp: TimeInterval?
    @State var brightnessStatusTask: Task<Void, Never>?
    @State var brightnessReturnStatus: IslandStatus = .closed
    @State var brightnessCollapseShowsMusic = true
    @State var pendingBrightnessEventTimestamp: TimeInterval?
    @State var lastBrightnessStatusEventTime: TimeInterval = 0
    @State var volumeStatusTask: Task<Void, Never>?
    @State var volumeReturnStatus: IslandStatus = .closed
    @State var volumeCollapseShowsMusic = true
    @State var pendingVolumeEventTimestamp: TimeInterval?
    @State var lastVolumeStatusEventTime: TimeInterval = 0
    @State var musicScrollGestureState: Int = 0
    @State var isPointerInsideIsland = false
    @State var playPauseBounce = false
    @State var skipIndicator: String?
    @State var showMusicVolumeControl = false
    @State var currentScreen: NSScreen?
    @State var resolvedClosedHeight: CGFloat = 36
    
    private func updateClosedHeight(for screen: NSScreen?) {
        let nextHeight = IslandHeightResolver.closedHeight(for: screen)
        guard resolvedClosedHeight != nextHeight else { return }
        resolvedClosedHeight = nextHeight
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .allowsHitTesting(false)

            activeModuleView
                .padding(.top, 0)
                .zIndex(10)
                .scaleEffect(hoverScale)
                .onHover { hovering in
                    handleHover(hovering)
                }
                .animation(.easeInOut(duration: 0.22), value: settingsManager.showBattery)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            handleAppear()
        }
        .onChange(of: batteryManager.isCharging) { _, newValue in
            handleChargingChange(newValue)
        }
        .onChange(of: currentMusicAutoOpenKey) { _, _ in
            handleMusicAutoExpand(isPlaying: musicManager.isPlaying)
            playPendingFocusEventIfReady()
            playPendingBrightnessEventIfReady()
            playPendingVolumeEventIfReady()
        }
        .onChange(of: dynamicManager.currentModule) { _, _ in
            playPendingFocusEventIfReady()
            playPendingBrightnessEventIfReady()
            playPendingVolumeEventIfReady()
        }
        .onChange(of: musicManager.isPlaying) { _, _ in
            playPendingFocusEventIfReady()
            playPendingBrightnessEventIfReady()
            playPendingVolumeEventIfReady()
        }
        .onChange(of: animationsEnabled) { _, _ in
            playPendingFocusEventIfReady()
            playPendingBrightnessEventIfReady()
            playPendingVolumeEventIfReady()
        }
        .onChange(of: status) { _, newValue in
            guard newValue != .opened else { return }
            guard showMusicVolumeControl else { return }
            showMusicVolumeControl = false
        }
        .onChange(of: focusManager.focusEventID) { _, eventID in
            guard eventID > 0 else { return }
            handleFocusEvent(isActive: focusManager.focusEventIsActive)
        }
        .onChange(of: brightnessManager.brightnessEventID) { _, eventID in
            guard eventID > 0 else { return }
            handleBrightnessEvent()
        }
        .onChange(of: musicManager.outputVolumeEventID) { _, eventID in
            guard eventID > 0 else { return }
            handleVolumeEvent()
        }
        .onChange(of: settingsManager.showFocusAnimations) { _, isEnabled in
            guard !isEnabled else { return }
            hideFocusStatusPreview()
        }
        .onChange(of: settingsManager.showBrightnessStatus) { _, isEnabled in
            guard !isEnabled else { return }
            hideBrightnessStatusPreview()
        }
        .onChange(of: settingsManager.showSoundStatus) { _, isEnabled in
            guard !isEnabled else { return }
            hideVolumeStatusPreview()
        }
        .animation(.interactiveSpring(duration: 0.32, extraBounce: 0.03), value: isHovered)
        .animation(animation, value: status)
        .animation(.easeInOut(duration: 0.18), value: focusStatusIsActive)
        .animation(animation, value: showMusicVolumeControl)
        .animation(.easeInOut(duration: 0.22), value: batteryManager.batteryLevel)
        .preferredColorScheme(.dark)
        .background(
            WindowScreenReader { screen in
                guard currentScreen !== screen else { return }
                currentScreen = screen
                updateClosedHeight(for: screen)
            }
        )
    }
}
