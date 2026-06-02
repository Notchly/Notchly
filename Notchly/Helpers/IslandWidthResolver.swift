//
//  IslandWidthResolver.swift
//  Notchly
//
//  Created by user on 31.05.2026.
//

import AppKit

enum IslandWidthResolver {
    static func idleWidth(for screen: NSScreen?, configuredIslandWidth: CGFloat) -> CGFloat {
        if let screen,
           screen.safeAreaInsets.top > 0,
           let topLeftArea = screen.auxiliaryTopLeftArea,
           let topRightArea = screen.auxiliaryTopRightArea {
            let notchWidth = screen.frame.width
                - topLeftArea.width
                - topRightArea.width

            if notchWidth.isFinite, notchWidth > 80 {
                return min(max(notchWidth, 120), configuredIslandWidth)
            }
        }

        return min(max(configuredIslandWidth * 0.58, 160), 210)
    }
}
