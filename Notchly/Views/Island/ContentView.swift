//
//  ContentView.swift
//  Notchly
//
//  Created by n0xbyte on 16.03.2026.
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
    @ObservedObject var agentEventManager: AgentEventManager
    @ObservedObject var lockScreenOverlayModel: LockScreenOverlayModel
    let animationsEnabled: Bool
    let onClosedHeightChange: (CGFloat) -> Void

    @State var status: IslandStatus = .closed
    @State var showChargingPop = false
    @State var isHovered = false
    @State var hasFinishedInitialAppear = false
    @State var autoExpandMusicTask: Task<Void, Never>?
    @State var focusStatusTask: Task<Void, Never>?
    @State var lastMusicAutoOpenKey: String = ""
    @State var stagedMusicAutoOpenKey: String = ""
    @State var lastMusicPauseDate: Date?
    @State var previewAutoCloseKey: String = ""
    @State var focusReturnStatus: IslandStatus = .closed
    @State var focusCollapseShowsMusic = true
    @State var focusStatusIsActive = false
    @State var hidesFocusStatusContentDuringReturn = false
    @State var pendingFocusEventIsActive = false
    @State var pendingFocusEventTimestamp: TimeInterval?
    @State var brightnessStatusTask: Task<Void, Never>?
    @State var brightnessReturnStatus: IslandStatus = .closed
    @State var brightnessCollapseShowsMusic = true
    @State var hidesBrightnessStatusContentDuringReturn = false
    @State var pendingBrightnessEventTimestamp: TimeInterval?
    @State var lastBrightnessStatusEventTime: TimeInterval = 0
    @State var volumeStatusTask: Task<Void, Never>?
    @State var volumeReturnStatus: IslandStatus = .closed
    @State var volumeCollapseShowsMusic = true
    @State var hidesVolumeStatusContentDuringReturn = false
    @State var pendingVolumeEventTimestamp: TimeInterval?
    @State var lastVolumeStatusEventTime: TimeInterval = 0
    @State var musicScrollGestureState: Int = 0
    @State var lastMusicTrackSwipeTime: TimeInterval = 0
    @State var isPointerInsideIsland = false
    @State var playPauseBounce = false
    @State var skipIndicator: String?
    @State var showMusicVolumeControl = false
    @State var isAgentMusicTransitionActive = false
    @State var agentMusicReturnStatus: IslandStatus = .closed
    @State var displayedAgentEvent: AgentEvent?
    @State var agentPresentationStartedAt: Date?
    @State var agentDismissTask: Task<Void, Never>?
    @State var agentPresentationTask: Task<Void, Never>?
    @State var showsStandaloneAgentContent = false
    @State var isStandaloneAgentClosing = false
    @State var showsAgentMusicContent = false
    @State var agentMusicContentAppeared = false
    @State var hidesMusicContentDuringAgentReturn = false
    @State var agentMusicHideTask: Task<Void, Never>?
    @State var agentCollapseShowsMusic = true
    @State var isAgentMusicClosing = false
    @State var idleNotchSizeSuppressed = false
    @State var musicStartUsesIdleWidth = false
    @State var musicStartWidthTask: Task<Void, Never>?
    @State var musicEndKeepsFullWidth = false
    @State var musicEndWidthTask: Task<Void, Never>?
    @State var currentScreen: NSScreen?
    @State var resolvedClosedHeight: CGFloat = 36
    
    private func updateClosedHeight(for screen: NSScreen?) {
        guard lockScreenOverlayModel.state == .music else { return }

        let nextHeight = IslandHeightResolver.closedHeight(for: screen)
        if resolvedClosedHeight != nextHeight {
            resolvedClosedHeight = nextHeight
        }
        onClosedHeightChange(nextHeight)
    }

    var body: some View {
        islandViewWithScreenReader
    }

    private var islandRootView: some View {
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
    }

    private var islandViewWithCoreHandlers: some View {
        islandRootView
        .onAppear {
            handleAppear()
        }
        .onDisappear {
            handleDisappear()
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
        .onChange(of: musicManager.isPlaying) { _, isPlaying in
            handleMusicPlaybackChange(isPlaying: isPlaying)
            playPendingFocusEventIfReady()
            playPendingBrightnessEventIfReady()
            playPendingVolumeEventIfReady()
        }
        .onChange(of: musicManager.hasNowPlayingContent) { _, hasNowPlayingContent in
            handleNowPlayingContentChange(hasNowPlayingContent)
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
    }

    private var islandViewWithNotificationHandlers: some View {
        islandViewWithCoreHandlers
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
        .onChange(of: agentEventManager.eventID) { _, eventID in
            guard eventID > 0 else { return }
            handleAgentEventChange(agentEventManager.currentEvent)
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
        .onChange(of: settingsManager.showBattery) { _, isEnabled in
            handleBatteryVisibilityChange(isEnabled)
        }
        .onChange(of: settingsManager.showMusic) { _, isEnabled in
            handleMusicVisibilityChange(isEnabled)
        }
    }

    private var islandViewWithAnimations: some View {
        islandViewWithNotificationHandlers
        .animation(animation, value: status)
        .animation(.easeInOut(duration: 0.18), value: focusStatusIsActive)
        .animation(animation, value: showMusicVolumeControl)
        .animation(.easeInOut(duration: 0.22), value: batteryManager.batteryLevel)
        .preferredColorScheme(.dark)
    }

    private var islandViewWithScreenReader: some View {
        islandViewWithAnimations
        .background(
            WindowScreenReader { screen in
                guard currentScreen !== screen else { return }
                currentScreen = screen
                updateClosedHeight(for: screen)
            }
        )
    }
}
