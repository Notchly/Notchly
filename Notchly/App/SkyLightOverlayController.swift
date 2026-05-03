//
//  SkyLightOverlayController.swift
//  Notchly
//
//  Created by user on 03.05.2026.
//

import AppKit
import SwiftUI
import SkyLightWindow

@MainActor
final class SkyLightOverlayController {
    private let environment: AppEnvironment
    private var windowController: NSWindowController?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func show() {
        guard windowController == nil else { return }
        guard let screen = NSScreen.main else { return }

        let view = AnyView(
            LockScreenOverlayRootView(
                model: environment.lockScreenOverlayModel,
                settingsManager: environment.settingsManager,
                batteryManager: environment.batteryManager,
                dynamicManager: environment.dynamicManager,
                musicManager: environment.musicManager,
                screenSize: screen.frame.size
            )
        )

        windowController = SkyLightOperator.shared.delegateView(view, toScreen: screen)
    }
}
