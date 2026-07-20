//
//  WhatsNewRelease.swift
//  Notchly
//
//  Created by n0xbyte on 19.07.2026.
//

import Foundation

struct WhatsNewRelease {
    static let version = "1.2.0"

    struct Feature: Identifiable {
        let id: String
        let title: String
        let description: String
    }

    let version: String
    let features: [Feature]

    static var current: WhatsNewRelease {
        WhatsNewRelease(
            version: version,
            features: [
                Feature(
                    id: "network-status",
                    title: "Network status at a glance",
                    description: "See when Wi-Fi connects, disconnects, or becomes unavailable directly in the island."
                ),
                Feature(
                    id: "personal-hotspot",
                    title: "Personal Hotspot alerts",
                    description: "Notchly now recognizes Personal Hotspot connections and lets you know when internet access is restored."
                ),
                Feature(
                    id: "network-transitions",
                    title: "Fluid island transitions",
                    description: "Network alerts open and close through smooth states that stay coordinated with Music and other notifications."
                ),
                Feature(
                    id: "network-setting",
                    title: "You're in control",
                    description: "Enable or disable network status notifications at any time from General Settings."
                ),
                Feature(
                    id: "reliability",
                    title: "Reliability improvements",
                    description: "This update reduces unnecessary network activity and improves updates and unlock sound playback."
                )
            ]
        )
    }
}
