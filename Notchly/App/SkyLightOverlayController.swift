//
//  SkyLightOverlayController.swift
//  Notchly
//
//  Created by n0xbyte on 03.05.2026.
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
    private var hideWhenFullscreenCancellable: AnyCancellable?
    private var lockStateCancellable: AnyCancellable?
    private var fullscreenDetectionTask: Task<Void, Never>?
    private var isIslandHiddenForFullscreen = false

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
        fullscreenDetectionTask?.cancel()
        fullscreenDetectionTask = nil
        displayTargetCancellable?.cancel()
        displayTargetCancellable = nil
        hideWhenFullscreenCancellable?.cancel()
        hideWhenFullscreenCancellable = nil
        lockStateCancellable?.cancel()
        lockStateCancellable = nil
        isIslandHiddenForFullscreen = false

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

        hideWhenFullscreenCancellable = environment.settingsManager.$hideNotchWhenFullscreen
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateFullscreenMonitoring()
                }
            }

        lockStateCancellable = environment.lockScreenOverlayModel.$state
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateOverlayWindows()
                    self?.updateFullscreenMonitoring()
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
        updateFullscreenMonitoring()
    }

    private func updateOverlayWindows() {
        guard let screen = currentScreen ?? targetScreen() else { return }
        currentScreen = screen

        switch environment.lockScreenOverlayModel.state {
        case .locked:
            lockScreenWindowCloseTask?.cancel()
            lockScreenWindowCloseTask = nil
            setIslandHiddenForFullscreen(false, on: screen)
            hideIslandWindowForLock()
            showLockScreenWindow(on: screen)

        case .music:
            if lockScreenWindowController == nil {
                showIslandWindow(on: screen)
            } else {
                scheduleLockScreenWindowCloseAfterUnlock(on: screen)
            }
        }
    }

    private func showIslandWindow(on screen: NSScreen) {
        if islandWindowController == nil {
            islandWindowController = makeIslandWindowController(on: screen)
        }

        updateIslandWindowFrame(on: screen)
        if isIslandHiddenForFullscreen {
            islandWindowController?.window?.orderOut(nil)
        } else {
            islandWindowController?.window?.orderFrontRegardless()
        }
    }

    private func hideIslandWindowForLock() {
        islandWindowController?.window?.orderOut(nil)
    }

    private func showLockScreenWindow(on screen: NSScreen) {
        guard lockScreenWindowController == nil else { return }

        let windowFrame = lockScreenWindowFrame(for: screen)
        let playerYPosition = lockScreenPlayerYPosition(for: screen)
        let view = AnyView(
            LockScreenOverlayRootView(
                model: environment.lockScreenOverlayModel,
                settingsManager: environment.settingsManager,
                musicManager: environment.musicManager,
                screenSize: windowFrame.size,
                lockScreenPlayerYPosition: playerYPosition,
                initialClosedHeight: IslandHeightResolver.closedHeight(for: screen)
            )
        )

        lockScreenWindowController = SkyLightOperator.shared.delegateView(view, toScreen: screen)
        lockScreenWindowController?.window?.setFrame(windowFrame, display: true)
        configureOverlayWindow(lockScreenWindowController?.window)
    }

    private func scheduleLockScreenWindowCloseAfterUnlock(on screen: NSScreen) {
        lockScreenWindowCloseTask?.cancel()

        lockScreenWindowCloseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(190))
            guard !Task.isCancelled else { return }
            guard self?.environment.lockScreenOverlayModel.state == .music else { return }

            self?.lockScreenWindowController?.close()
            self?.lockScreenWindowController = nil
            self?.showIslandWindow(on: screen)
            self?.updateFullscreenMonitoring()
            self?.lockScreenWindowCloseTask = nil
        }
    }

    private func updateFullscreenMonitoring() {
        let shouldMonitor = environment.settingsManager.hideNotchWhenFullscreen &&
            environment.lockScreenOverlayModel.state == .music

        guard shouldMonitor else {
            fullscreenDetectionTask?.cancel()
            fullscreenDetectionTask = nil

            if let screen = currentScreen ?? targetScreen() {
                setIslandHiddenForFullscreen(false, on: screen)
            }
            return
        }

        if fullscreenDetectionTask == nil {
            fullscreenDetectionTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    self?.evaluateFullscreenVisibility()
                    try? await Task.sleep(for: .milliseconds(650))
                }
            }
        }

        evaluateFullscreenVisibility()
    }

    private func evaluateFullscreenVisibility() {
        guard environment.settingsManager.hideNotchWhenFullscreen,
              environment.lockScreenOverlayModel.state == .music,
              let screen = currentScreen ?? targetScreen() else {
            return
        }

        setIslandHiddenForFullscreen(isFullscreenAppActive(on: screen), on: screen)
    }

    private func setIslandHiddenForFullscreen(_ hidden: Bool, on screen: NSScreen) {
        guard isIslandHiddenForFullscreen != hidden else { return }

        isIslandHiddenForFullscreen = hidden

        if hidden {
            islandWindowController?.window?.orderOut(nil)
        } else if environment.lockScreenOverlayModel.state == .music {
            showIslandWindow(on: screen)
        }
    }

    private func isFullscreenAppActive(on screen: NSScreen) -> Bool {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication,
              frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return false
        }

        let targetPID = frontmostApplication.processIdentifier
        let screenSize = screen.frame.size
        let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]

        return windowInfoList?.contains { info in
            guard windowOwnerPID(in: info) == targetPID,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = windowBounds(in: info) else {
                return false
            }

            return bounds.width >= screenSize.width - 4 && bounds.height >= screenSize.height - 4
        } ?? false
    }

    private func windowOwnerPID(in info: [String: Any]) -> pid_t? {
        if let pid = info[kCGWindowOwnerPID as String] as? pid_t {
            return pid
        }

        if let pid = info[kCGWindowOwnerPID as String] as? Int {
            return pid_t(pid)
        }

        return nil
    }

    private func windowBounds(in info: [String: Any]) -> CGRect? {
        guard let boundsInfo = info[kCGWindowBounds as String] as? [String: Any] else {
            return nil
        }

        let x = numericValue(boundsInfo["X"]) ?? 0
        let y = numericValue(boundsInfo["Y"]) ?? 0
        guard let width = numericValue(boundsInfo["Width"]),
              let height = numericValue(boundsInfo["Height"]) else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func numericValue(_ value: Any?) -> CGFloat? {
        switch value {
        case let value as CGFloat:
            return value
        case let value as Double:
            return CGFloat(value)
        case let value as Float:
            return CGFloat(value)
        case let value as Int:
            return CGFloat(value)
        case let value as NSNumber:
            return CGFloat(truncating: value)
        default:
            return nil
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

    private func lockScreenPlayerYPosition(for screen: NSScreen) -> CGFloat {
        min(max(screen.frame.height * 0.68, 500), screen.frame.height - 130)
    }

    private func lockScreenWindowFrame(for screen: NSScreen) -> NSRect {
        let playerYPosition = lockScreenPlayerYPosition(for: screen)
        let playerHeight: CGFloat = 168
        let verticalPadding: CGFloat = 32
        let requiredHeight = playerYPosition + playerHeight / 2 + verticalPadding
        let height = min(screen.frame.height, max(280, requiredHeight))
        let width = max(islandWindowSize.width, CGFloat(environment.settingsManager.islandWidth) + 40)

        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
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
