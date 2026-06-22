//
//  AppDelegate.swift
//  Notchly
//
//  Created by n0xbyte on 16.03.2026.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let environment = AppEnvironment()
    private var startupTask: Task<Void, Never>?

    private lazy var menuController = AppMenuController(
        settingsWindow: environment.settingsWindow,
        updaterController: environment.updaterController,
        agentEventManager: environment.agentEventManager
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
        environment.agentEventManager.start()
        environment.musicManager.start()
        overlayController.show()

        startupTask?.cancel()
        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self.environment.focusManager.start()
            self.lockScreenController.start()

            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self.environment.brightnessManager.start()
            self.startupTask = nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        startupTask?.cancel()
        startupTask = nil
        environment.musicManager.stop()
        environment.agentEventManager.stop()
        environment.focusManager.stop()
        environment.brightnessManager.stop()
        lockScreenController.stop()
        overlayController.stop()
    }
}
