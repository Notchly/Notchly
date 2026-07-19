//
//  WhatsNewRelease.swift
//  Notchly
//
//  Created by n0xbyte on 19.07.2026.
//

import Foundation

struct WhatsNewRelease {
    static let version = "1.1.6"

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
                    id: "lock-screen-player",
                    title: "A richer Lock Screen player",
                    description: "Enjoy expanded artwork, improved layouts, and more room for what is playing."
                ),
                Feature(
                    id: "smoother-transitions",
                    title: "Smoother transitions",
                    description: "Lock, unlock, and artwork transitions now feel faster and more responsive."
                ),
                Feature(
                    id: "media-reliability",
                    title: "More reliable media controls",
                    description: "Notchly follows the active media source more accurately when several apps are open."
                )
            ]
        )
    }
}
