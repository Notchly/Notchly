//
//  LockScreenOverlayState.swift
//  Notchly
//
//  Created by n0xbyte on 03.05.2026.
//

import Combine

enum LockScreenOverlayState: Equatable {
    case locked
    case music
}

enum LockScreenTransitionTiming {
    static let unlockIconDelay: TimeInterval = 0.02
    static let islandMorphDuration: TimeInterval = 0.42
    static let unlockMorphDuration: TimeInterval = 0.56
    static let overlayFadeStartDelay = unlockMorphDuration
    static let overlayFadeDuration: TimeInterval = 0.12
    static let windowCloseDelayMilliseconds = 740
}

@MainActor
final class LockScreenOverlayModel: ObservableObject {
    @Published var state: LockScreenOverlayState = .music
    @Published var isArtworkExpanded = false
    @Published var prefersExpandedArtwork = false
}
