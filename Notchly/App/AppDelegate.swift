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
    private var didValidateSingleInstance = false

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

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard validateSingleRunningInstance() else { return }
        environment.lockScreenWallpaperManager.recoverSynchronously()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard validateSingleRunningInstance() else { return }

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
        environment.lockScreenWallpaperManager.restoreSynchronously()
    }

    @discardableResult
    private func validateSingleRunningInstance() -> Bool {
        guard !didValidateSingleInstance else { return true }
        didValidateSingleInstance = true

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return true
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentProcessIdentifier }

        guard let existingInstance = otherInstances.first else {
            return true
        }

        existingInstance.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.terminate(nil)
        return false
    }
}
