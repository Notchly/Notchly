//
//  SettingsSection.swift
//  Notchly
//
//  Created by user on 29.04.2026.
//

import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general = "General"
    case focus = "Focus"
    case brightness = "Brightness"
    case sound = "Sound"
    case music = "Now Playing"
    case codex = "Codex"
    case battery = "Battery"
    case about = "About"

    var id: Self { self }

    var iconName: String {
        switch self {
        case .general:
            return "gear"
        case .focus:
            return "moon.fill"
        case .brightness:
            return "sun.max.fill"
        case .sound:
            return "speaker.wave.2.fill"
        case .music:
            return "music.note"
        case .codex:
            return "sparkles"
        case .battery:
            return "bolt.fill"
        case .about:
            return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general:
            return .blue
        case .focus:
            return .indigo
        case .brightness:
            return .yellow
        case .sound:
            return .orange
        case .music:
            return .red
        case .codex:
            return .mint
        case .battery:
            return .green
        case .about:
            return .gray
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Configure the core Notchly experience."
        case .focus:
            return "Customize Focus status animations."
        case .brightness:
            return "Customize brightness status and indicator layout."
        case .sound:
            return "Customize sound status and indicator layout."
        case .music:
            return "Customize now playing controls and previews."
        case .codex:
            return "Configure Codex hooks, sound, and alert timing."
        case .battery:
            return "Control battery indicators and charging feedback."
        case .about:
            return "Version, links, and app information."
        }
    }
}
