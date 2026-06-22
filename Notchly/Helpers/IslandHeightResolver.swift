//
//  IslandHeightResolver.swift
//  Notchly
//
//  Created by n0xbyte on 27.04.2026.
//

import AppKit

enum IslandHeightResolver {
    static let fallbackHeight: CGFloat = 36

    static func closedHeight(for screen: NSScreen?) -> CGFloat {
        guard let screen else {
            return fallbackHeight
        }

        let topSafeInset = screen.safeAreaInsets.top
        if topSafeInset > 0 {
            return topSafeInset
        }

        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        return menuBarHeight > 0 ? menuBarHeight : fallbackHeight
    }
}
