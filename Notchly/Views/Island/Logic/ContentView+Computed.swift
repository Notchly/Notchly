//
//  ContentView+Computed.swift
//  Notchly
//
//  Created by n0xbyte on 25.03.2026.
//

import SwiftUI
import AppKit

extension ContentView {
    var layout: IslandLayout {
        IslandLayout(
            status: layoutStatus,
            isMusicModule: usesMusicLayout,
            showChargingPop: showChargingPop,
            isMusicVolumeControlExpanded: showMusicVolumeControl,
            closedHeight: closedHeight,
            islandWidth: effectiveIslandWidth,
            allowsCompactBaseWidth: musicStartUsesIdleWidth,
            idleWidthOverride: configuredIdleIslandWidth
        )
    }

    var activeModuleView: some View {
        Group {
            if isAgentMusicTransitionActive {
                musicContainer
            } else if isStandaloneAgentPresentationActive {
                agentContainer
            } else if dynamicManager.currentModule == .agent,
                      agentEventManager.currentEvent == nil,
                      settingsManager.showMusic,
                      musicManager.hasNowPlayingContent {
                musicContainer
            } else if dynamicManager.currentModule == .agent {
                agentContainer
            } else if status == .focusCollapse ||
                status == .focusPreview ||
                status == .brightnessCollapse ||
                status == .brightnessPreview ||
                status == .volumeCollapse ||
                status == .volumePreview {
                musicContainer
            } else if settingsManager.showMusic &&
                musicManager.hasNowPlayingContent &&
                (musicStartUsesIdleWidth || !stagedMusicAutoOpenKey.isEmpty) {
                musicContainer
            } else {
                switch dynamicManager.currentModule {
                case .agent:
                    agentContainer
                case .battery:
                    if settingsManager.showBattery {
                        islandContainer
                    } else {
                        emptyBar
                    }
                case .music:
                    musicContainer
                case .none:
                    emptyBar
                }
            }
        }
    }

    var layoutStatus: IslandStatus {
        return status
    }

    var usesMusicLayout: Bool {
        if dynamicManager.currentModule == .music || isAgentMusicTransitionActive {
            return true
        }

        guard settingsManager.showMusic,
              musicManager.hasNowPlayingContent else { return false }

        switch status {
        case .opened, .musicPreview, .agentCollapse, .agentPreview:
            return true
        case .closed, .popping, .focusCollapse, .focusPreview, .brightnessCollapse, .brightnessPreview, .volumeCollapse, .volumePreview:
            return false
        }
    }

    var canShowAgentOverMusic: Bool {
        guard settingsManager.showMusic else { return false }
        guard musicManager.isPlaying else { return false }
        guard musicManager.hasNowPlayingContent else { return false }

        switch status {
        case .closed, .opened, .musicPreview:
            return true
        case .popping, .focusCollapse, .focusPreview, .brightnessCollapse, .brightnessPreview, .volumeCollapse, .volumePreview, .agentCollapse, .agentPreview:
            return false
        }
    }

    var showsAgentOverMusic: Bool {
        agentEventManager.currentEvent != nil && canShowAgentOverMusic
    }

    var activeAgentEvent: AgentEvent? {
        displayedAgentEvent ?? agentEventManager.currentEvent
    }

    var isStandaloneAgentPresentationActive: Bool {
        guard !isAgentMusicTransitionActive else { return false }
        guard activeAgentEvent != nil else { return false }
        return status == .agentPreview || status == .agentCollapse
    }

    var isAgentAlertBlockingOtherEvents: Bool {
        activeAgentEvent != nil || isAgentMusicTransitionActive
    }

    var closedHeight: CGFloat {
        resolvedClosedHeight
    }

    var configuredBaseIslandWidth: CGFloat {
        min(max(CGFloat(settingsManager.islandWidth), 280), 360)
    }

    var configuredIdleIslandWidth: CGFloat {
        IslandWidthResolver.idleWidth(
            for: currentScreen,
            configuredIslandWidth: configuredBaseIslandWidth
        )
    }

    var effectiveIslandWidth: CGFloat {
        guard musicStartUsesIdleWidth,
              status == .closed else {
            return CGFloat(settingsManager.islandWidth)
        }

        return configuredIdleIslandWidth + (isHovered ? 8 : 0)
    }

    var usesIdleNotchSize: Bool {
        guard status == .closed else { return false }
        guard agentEventManager.currentEvent == nil else { return false }
        guard !showChargingPop else { return false }
        guard !musicEndKeepsFullWidth else { return false }
        guard !musicStartUsesIdleWidth else { return true }
        guard !musicManager.hasNowPlayingContent else { return false }

        return dynamicManager.currentModule == .none || dynamicManager.currentModule == .battery
    }

    var idleNotchSize: CGSize {
        usesIdleNotchSize && isHovered ? layout.idleHoverSize : layout.idleSize
    }

    var hoverScale: CGFloat {
        if usesIdleNotchSize {
            return 1.0
        }

        guard isHovered else { return 1.0 }

        switch status {
        case .closed:
            return 1.02
        case .popping:
            return 1.02
        case .opened:
            return 1.012
        case .musicPreview:
            return 1.01
        case .focusCollapse:
            return 1.0
        case .focusPreview:
            return 1.01
        case .brightnessCollapse:
            return 1.0
        case .brightnessPreview:
            return 1.01
        case .volumeCollapse:
            return 1.0
        case .volumePreview:
            return 1.01
        case .agentCollapse:
            return 1.0
        case .agentPreview:
            return 1.01
        }
    }

    var hoverOffsetY: CGFloat {
        return isHovered ? 3 : 0
    }

    var currentMusicAutoOpenKey: String {
        [
            musicManager.trackTitle,
            musicManager.artistName,
            musicManager.albumTitle,
            musicManager.sourceName
        ].joined(separator: "|")
    }

    var artworkTransitionKey: String {
        "\(musicManager.trackTitle)|\(musicManager.artistName)|\(musicManager.albumTitle)"
    }

    var musicProgress: CGFloat {
        guard musicManager.durationMs > 0 else { return 0 }
        return CGFloat(min(max(musicManager.playbackPosition / musicManager.durationMs, 0), 1))
    }

    var isLivestream: Bool {
        musicManager.durationMs <= 0
    }

    var combinedPreviewText: String {
        let title = musicManager.trackTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = musicManager.artistName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !title.isEmpty && !artist.isEmpty {
            return "\(title) — \(artist)"
        } else if !title.isEmpty {
            return title
        } else if !artist.isEmpty {
            return artist
        } else {
            return "Now Playing"
        }
    }

    var closedIconColor: Color {
        if batteryManager.isCharging { return .green }
        if batteryManager.batteryLevel <= settingsManager.lowBatteryThreshold { return .red }
        return .white
    }

    var closedTextColor: Color {
        if batteryManager.batteryLevel <= settingsManager.lowBatteryThreshold && !batteryManager.isCharging {
            return Color(red: 1.0, green: 0.83, blue: 0.83)
        }
        return .white
    }

    var progressColor: Color {
        if batteryManager.isCharging { return .green }
        if batteryManager.batteryLevel <= settingsManager.lowBatteryThreshold { return .red }
        return .white
    }

    var batterySymbolName: String {
        switch batteryManager.batteryLevel {
        case 0..<10: return "battery.0"
        case 10..<40: return "battery.25"
        case 40..<70: return "battery.50"
        case 70..<90: return "battery.75"
        default: return "battery.100"
        }
    }

    var stateText: String {
        if batteryManager.isCharging { return "Charging" }
        if batteryManager.batteryLevel <= settingsManager.lowBatteryThreshold { return "Low Battery" }
        return "Battery"
    }

    var animation: Animation {
        .interactiveSpring(duration: 0.5, extraBounce: 0.01, blendDuration: 0.125)
    }

    var agentMusicHeightAnimation: Animation {
        .smooth(duration: 0.68, extraBounce: 0)
    }
    
    func formatPlaybackTime(_ totalSeconds: TimeInterval) -> String {
        let seconds = max(0, Int(totalSeconds.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
