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
    case music = "Now Playing"
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
        case .music:
            return "music.note"
        case .battery:
            return "battery.100"
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
        case .music:
            return .red
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
        case .music:
            return "Customize now playing controls and previews."
        case .battery:
            return "Control battery indicators and charging feedback."
        case .about:
            return "Version, links, and app information."
        }
    }
}
