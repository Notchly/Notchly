//
//  IslandLayout.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI

struct IslandLayout {
    let status: IslandStatus
    let isMusicModule: Bool
    let showChargingPop: Bool
    let closedHeight: CGFloat

    let spacing: CGFloat = 10

    var closedSize: CGSize {
        CGSize(width: 318, height: closedHeight)
    }

    var openedSize: CGSize {
        CGSize(width: 318, height: 132)
    }

    var musicOpenedSize: CGSize {
        CGSize(width: 318, height: 190)
    }

    var musicPreviewSize: CGSize {
        CGSize(width: 318, height: 68)
    }

    var chargingSize: CGSize {
        CGSize(width: 280, height: closedHeight)
    }

    var islandSize: CGSize {
        switch status {
        case .closed:
            return closedSize
        case .opened:
            return isMusicModule ? musicOpenedSize : openedSize
        case .popping:
            return showChargingPop ? chargingSize : closedSize
        case .musicPreview:
            return musicPreviewSize
        }
    }

    var cornerRadius: CGFloat {
        switch status {
        case .closed:
            return 8
        case .opened:
            return 32
        case .popping:
            return 10
        case .musicPreview:
            return 24
        }
    }
}
