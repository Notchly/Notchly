//
//  SkyLightOverlayController.swift
//  Notchly
//
//  Created by user on 03.05.2026.
//

import AppKit
import Combine
import SwiftUI
import SkyLightWindow

@MainActor
final class SkyLightOverlayController {
    private let environment: AppEnvironment
    private var islandWindowController: NSWindowController?
    private var lockScreenWindowController: NSWindowController?
    private var screenChangeObserver: NSObjectProtocol?
    private var screenRefreshTask: Task<Void, Never>?
    private var lockScreenWindowCloseTask: Task<Void, Never>?
    private var currentScreenID: CGDirectDisplayID?
    private var currentScreen: NSScreen?
    private var displayTargetCancellable: AnyCancellable?
    private var lockStateCancellable: AnyCancellable?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func show() {
        installScreenObserver()
        installSettingsObserver()
        updateOverlayScreen(force: true)
    }

    func stop() {
        screenRefreshTask?.cancel()
        screenRefreshTask = nil
        lockScreenWindowCloseTask?.cancel()
        lockScreenWindowCloseTask = nil
        displayTargetCancellable?.cancel()
        displayTargetCancellable = nil
        lockStateCancellable?.cancel()
        lockStateCancellable = nil

        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
            self.screenChangeObserver = nil
        }

        islandWindowController?.close()
        islandWindowController = nil
        lockScreenWindowController?.close()
        lockScreenWindowController = nil
        currentScreenID = nil
        currentScreen = nil
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

    private func installSettingsObserver() {
        guard displayTargetCancellable == nil else { return }

        displayTargetCancellable = environment.settingsManager.$displayTarget
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateOverlayScreen(force: true)
                }
            }

        lockStateCancellable = environment.lockScreenOverlayModel.$state
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateOverlayWindows()
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
        guard force || islandWindowController == nil || currentScreenID != screenID else { return }

        islandWindowController?.close()
        islandWindowController = nil
        lockScreenWindowController?.close()
        lockScreenWindowController = nil
        lockScreenWindowCloseTask?.cancel()
        lockScreenWindowCloseTask = nil

        currentScreen = screen
        currentScreenID = screenID
        updateOverlayWindows()
    }

    private func updateOverlayWindows() {
        guard let screen = currentScreen ?? targetScreen() else { return }
        currentScreen = screen

        switch environment.lockScreenOverlayModel.state {
        case .locked:
            lockScreenWindowCloseTask?.cancel()
            lockScreenWindowCloseTask = nil
            closeIslandWindow()
            showLockScreenWindow(on: screen)

        case .music:
            if lockScreenWindowController == nil {
                showIslandWindow(on: screen)
            } else {
                scheduleIslandWindowAfterUnlock(on: screen)
                scheduleLockScreenWindowCloseAfterUnlock()
            }
        }
    }

    private func showIslandWindow(on screen: NSScreen) {
        if islandWindowController == nil {
            islandWindowController = makeIslandWindowController(on: screen)
        }

        updateIslandWindowFrame(on: screen)
        islandWindowController?.window?.orderFrontRegardless()
    }

    private func closeIslandWindow() {
        islandWindowController?.close()
        islandWindowController = nil
    }

    private func showLockScreenWindow(on screen: NSScreen) {
        guard lockScreenWindowController == nil else { return }

        let view = AnyView(
            LockScreenOverlayRootView(
                model: environment.lockScreenOverlayModel,
                settingsManager: environment.settingsManager,
                musicManager: environment.musicManager,
                screenSize: screen.frame.size,
                initialClosedHeight: IslandHeightResolver.closedHeight(for: screen)
            )
        )

        lockScreenWindowController = SkyLightOperator.shared.delegateView(view, toScreen: screen)
        configureOverlayWindow(lockScreenWindowController?.window)
    }

    private func scheduleIslandWindowAfterUnlock(on screen: NSScreen) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            guard self?.environment.lockScreenOverlayModel.state == .music else { return }
            self?.showIslandWindow(on: screen)
        }
    }

    private func scheduleLockScreenWindowCloseAfterUnlock() {
        lockScreenWindowCloseTask?.cancel()

        lockScreenWindowCloseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(190))
            guard !Task.isCancelled else { return }
            guard self?.environment.lockScreenOverlayModel.state == .music else { return }

            self?.lockScreenWindowController?.close()
            self?.lockScreenWindowController = nil
            self?.lockScreenWindowCloseTask = nil
        }
    }

    private func makeIslandWindowController(on screen: NSScreen) -> NSWindowController {
        let size = islandWindowSize
        let window = NSPanel(
            contentRect: islandWindowFrame(for: screen, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.level = .init(rawValue: Int(Int32.max - 3))
        window.collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        window.canBecomeVisibleWithoutLogin = true
        configureOverlayWindow(window)

        let view = ContentView(
            batteryManager: environment.batteryManager,
            settingsManager: environment.settingsManager,
            dynamicManager: environment.dynamicManager,
            musicManager: environment.musicManager,
            focusManager: environment.focusManager,
            brightnessManager: environment.brightnessManager,
            agentEventManager: environment.agentEventManager,
            animationsEnabled: true
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        window.contentViewController = NSHostingController(rootView: view)
        SkyLightOperator.shared.delegateWindow(window)

        return NSWindowController(window: window)
    }

    private func updateIslandWindowFrame(on screen: NSScreen) {
        guard let window = islandWindowController?.window else { return }
        window.setFrame(islandWindowFrame(for: screen, size: islandWindowSize), display: true)
    }

    private var islandWindowSize: CGSize {
        CGSize(width: 456, height: 280)
    }

    private func islandWindowFrame(for screen: NSScreen, size: CGSize) -> NSRect {
        NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func configureOverlayWindow(_ window: NSWindow?) {
        guard let window else { return }
        window.acceptsMouseMovedEvents = false
    }

    private func targetScreen() -> NSScreen? {
        let screens = NSScreen.screens

        guard !screens.isEmpty else { return nil }

        switch environment.settingsManager.displayTarget {
        case .main:
            return NSScreen.main
                ?? screens.first

        case .builtIn:
            return builtInScreen(in: screens)
                ?? primaryNotchedScreen(in: screens)
                ?? NSScreen.main
                ?? screens.first
        }
    }

    private func primaryNotchedScreen(in screens: [NSScreen]) -> NSScreen? {
        return screens
            .max { lhs, rhs in
                lhs.safeAreaInsets.top < rhs.safeAreaInsets.top
            }
            .flatMap { $0.safeAreaInsets.top > 0 ? $0 : nil }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }

    private func builtInScreen(in screens: [NSScreen]) -> NSScreen? {
        screens.first { screen in
            guard let displayID = displayID(for: screen) else { return false }
            return CGDisplayIsBuiltin(displayID) != 0
        }
    }
}
