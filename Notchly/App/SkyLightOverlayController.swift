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
    private var screenChangeObserver: NSObjectProtocol?
    private var screenRefreshTask: Task<Void, Never>?
    private var currentScreenID: CGDirectDisplayID?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func show() {
        installScreenObserver()
        updateOverlayScreen(force: true)
    }

    func stop() {
        screenRefreshTask?.cancel()
        screenRefreshTask = nil

        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
            self.screenChangeObserver = nil
        }

        windowController?.close()
        windowController = nil
        currentScreenID = nil
    }

    private func installScreenObserver() {
        guard screenChangeObserver == nil else { return }

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleOverlayScreenRefresh()
            }
        }
    }

    private func scheduleOverlayScreenRefresh() {
        screenRefreshTask?.cancel()

        screenRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.screenRefreshTask = nil
                self?.updateOverlayScreen()
            }
        }
    }

    private func updateOverlayScreen(force: Bool = false) {
        guard let screen = targetScreen() else { return }

        let screenID = displayID(for: screen)
        guard force || windowController == nil || currentScreenID != screenID else { return }

        windowController?.close()

        let view = AnyView(
            LockScreenOverlayRootView(
                model: environment.lockScreenOverlayModel,
                settingsManager: environment.settingsManager,
                focusManager: environment.focusManager,
                batteryManager: environment.batteryManager,
                dynamicManager: environment.dynamicManager,
                musicManager: environment.musicManager,
                screenSize: screen.frame.size
            )
        )

        windowController = SkyLightOperator.shared.delegateView(view, toScreen: screen)
        currentScreenID = screenID
    }

    private func targetScreen() -> NSScreen? {
        let screens = NSScreen.screens

        return screens
            .max { lhs, rhs in
                lhs.safeAreaInsets.top < rhs.safeAreaInsets.top
            }
            .flatMap { $0.safeAreaInsets.top > 0 ? $0 : nil }
            ?? NSScreen.main
            ?? screens.first
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }
}
