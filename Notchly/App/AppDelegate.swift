//
//  AppDelegate.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let environment = AppEnvironment()

    private lazy var menuController = AppMenuController(
        settingsWindow: environment.settingsWindow,
        updaterController: environment.updaterController
    )

    private lazy var lockScreenController = LockScreenStateController(
        model: environment.lockScreenOverlayModel
    )

    private lazy var overlayController = SkyLightOverlayController(
        environment: environment
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menuController.install()
        lockScreenController.start()
        overlayController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        lockScreenController.stop()
    }
}
