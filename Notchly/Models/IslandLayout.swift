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
    let isMusicVolumeControlExpanded: Bool
    let closedHeight: CGFloat
    let islandWidth: CGFloat
    let allowsCompactBaseWidth: Bool
    let idleWidthOverride: CGFloat?

    let spacing: CGFloat = 10

    var baseWidth: CGFloat {
        min(max(islandWidth, allowsCompactBaseWidth ? 160 : 280), 360)
    }

    var closedSize: CGSize {
        CGSize(width: baseWidth, height: closedHeight)
    }

    var idleWidth: CGFloat {
        if let idleWidthOverride {
            return min(max(idleWidthOverride, 120), baseWidth)
        }

        return min(max(baseWidth * 0.58, 160), 210)
    }

    var idleSize: CGSize {
        CGSize(width: idleWidth, height: closedHeight)
    }

    var idleHoverSize: CGSize {
        CGSize(width: idleWidth + 8, height: closedHeight)
    }

    var openedSize: CGSize {
        CGSize(width: baseWidth, height: 132)
    }

    var musicOpenedSize: CGSize {
        CGSize(width: baseWidth, height: isMusicVolumeControlExpanded ? 228 : 190)
    }

    var musicPreviewSize: CGSize {
        CGSize(width: baseWidth, height: 68)
    }

    var focusPreviewSize: CGSize {
        closedSize
    }

    var focusCollapsedSize: CGSize {
        CGSize(width: closedSize.width * 0.5, height: closedHeight)
    }

    var brightnessPreviewSize: CGSize {
        closedSize
    }

    var brightnessCollapsedSize: CGSize {
        CGSize(width: closedSize.width * 0.5, height: closedHeight)
    }

    var volumePreviewSize: CGSize {
        closedSize
    }

    var volumeCollapsedSize: CGSize {
        CGSize(width: closedSize.width * 0.5, height: closedHeight)
    }

    var agentPreviewSize: CGSize {
        musicPreviewSize
    }

    var agentCollapsedSize: CGSize {
        CGSize(width: closedSize.width * 0.5, height: closedHeight)
    }

    var chargingSize: CGSize {
        CGSize(width: max(280, baseWidth - 38), height: closedHeight)
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
        case .focusCollapse:
            return focusCollapsedSize
        case .focusPreview:
            return focusPreviewSize
        case .brightnessCollapse:
            return brightnessCollapsedSize
        case .brightnessPreview:
            return brightnessPreviewSize
        case .volumeCollapse:
            return volumeCollapsedSize
        case .volumePreview:
            return volumePreviewSize
        case .agentCollapse:
            return agentCollapsedSize
        case .agentPreview:
            return agentPreviewSize
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
        case .focusCollapse:
            return 8
        case .focusPreview:
            return 8
        case .brightnessCollapse:
            return 8
        case .brightnessPreview:
            return 8
        case .volumeCollapse:
            return 8
        case .volumePreview:
            return 8
        case .agentCollapse:
            return 8
        case .agentPreview:
            return 24
        }
    }
}
