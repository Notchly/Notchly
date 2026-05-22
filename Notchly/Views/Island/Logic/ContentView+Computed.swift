//
//  ContentView+Computed.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI
import AppKit

extension ContentView {
    var layout: IslandLayout {
        IslandLayout(
            status: status,
            isMusicModule: dynamicManager.currentModule == .music,
            showChargingPop: showChargingPop,
            isMusicVolumeControlExpanded: showMusicVolumeControl,
            closedHeight: closedHeight
        )
    }

    var activeModuleView: some View {
        Group {
            if status == .focusCollapse || status == .focusPreview {
                musicContainer
            } else {
                switch dynamicManager.currentModule {
                case .battery:
                    islandContainer
                case .music:
                    musicContainer
                case .none:
                    emptyBar
                }
            }
        }
    }

    var closedHeight: CGFloat {
        resolvedClosedHeight
    }

    var hoverScale: CGFloat {
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
