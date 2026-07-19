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

@MainActor
final class LockScreenOverlayModel: ObservableObject {
    @Published var state: LockScreenOverlayState = .music
    @Published var isArtworkExpanded = false
}
