//
//  IslandHeightResolver.swift
//  Notchly
//
//  Created by user on 27.04.2026.
//

import AppKit

enum IslandHeightResolver {
    static let fallbackHeight: CGFloat = 36

    static func closedHeight(for screen: NSScreen?) -> CGFloat {
        let lockedExtraHeight: CGFloat = isScreenLocked() ? 1 : 0

        guard let screen else {
            return fallbackHeight + lockedExtraHeight
        }

        let topSafeInset = screen.safeAreaInsets.top
        if topSafeInset > 0 {
            return topSafeInset + lockedExtraHeight
        }

        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        let baseHeight = menuBarHeight > 0 ? menuBarHeight : fallbackHeight

        return baseHeight + lockedExtraHeight
    }
}
