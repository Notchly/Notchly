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
    private var fullscreenRefreshTask: Task<Void, Never>?
    private var currentScreenID: CGDirectDisplayID?
    private var currentScreen: NSScreen?
    private var currentClosedHeight = IslandHeightResolver.fallbackHeight
    private var displayTargetCancellable: AnyCancellable?
    private var hideWhenFullscreenCancellable: AnyCancellable?
    private var lockStateCancellable: AnyCancellable?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var activeSpaceObserver: NSObjectProtocol?
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
        fullscreenRefreshTask?.cancel()
        fullscreenRefreshTask = nil
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

        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
            self.workspaceActivationObserver = nil
        }

        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
            self.activeSpaceObserver = nil
        }

        islandWindowController?.close()
        islandWindowController = nil
        lockScreenWindowController?.close()
        lockScreenWindowController = nil
        environment.lockScreenOverlayModel.isArtworkExpanded = false
        currentScreenID = nil
        currentScreen = nil
        currentClosedHeight = IslandHeightResolver.fallbackHeight
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
        let didChangeDisplay = currentScreenID != screenID

        if !force, islandWindowController != nil, !didChangeDisplay {
            currentScreen = screen
            updateIslandWindowFrame(on: screen)

            if environment.lockScreenOverlayModel.state == .locked,
               let lockScreenWindow = lockScreenWindowController?.window,
               !framesMatchOnBackingGrid(
                   lockScreenWindow.frame,
                   lockScreenWindowFrame(for: screen),
                   scale: screen.backingScaleFactor
               ) {
                lockScreenWindowController?.close()
                lockScreenWindowController = nil
                showLockScreenWindow(on: screen)
            }

            return
        }

        islandWindowController?.close()
        islandWindowController = nil
        lockScreenWindowController?.close()
        lockScreenWindowController = nil
        lockScreenWindowCloseTask?.cancel()
        lockScreenWindowCloseTask = nil

        currentScreen = screen
        currentScreenID = screenID
        currentClosedHeight = IslandHeightResolver.closedHeight(for: screen)
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
            keepIslandWindowVisibleBehindLock()
            showLockScreenWindow(on: screen)

        case .music:
            if lockScreenWindowController == nil {
                environment.lockScreenOverlayModel.isArtworkExpanded = false
                environment.lockScreenWallpaperManager.restore()
                showIslandWindow(on: screen)
            } else {
                scheduleLockScreenWindowCloseAfterUnlock()
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

    private func keepIslandWindowVisibleBehindLock() {
        islandWindowController?.window?.orderFrontRegardless()
    }

    private func showLockScreenWindow(on screen: NSScreen) {
        guard lockScreenWindowController == nil else { return }

        environment.lockScreenOverlayModel.isArtworkExpanded = false

        let windowFrame = lockScreenWindowFrame(for: screen)
        let playerYPosition = lockScreenPlayerYPosition(for: screen)
        let expandedArtworkSize = lockScreenArtworkSize(for: screen)
        let view = AnyView(
            LockScreenOverlayRootView(
                model: environment.lockScreenOverlayModel,
                settingsManager: environment.settingsManager,
                musicManager: environment.musicManager,
                wallpaperManager: environment.lockScreenWallpaperManager,
                wallpaperScreen: screen,
                screenSize: windowFrame.size,
                lockScreenPlayerYPosition: playerYPosition,
                expandedArtworkSize: expandedArtworkSize,
                initialClosedHeight: currentClosedHeight
            )
        )

        let window = NSPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.hidesOnDeactivate = false
        window.isMovable = false
        window.level = .init(rawValue: Int(Int32.max - 2))
        window.collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        window.canBecomeVisibleWithoutLogin = true
        window.contentViewController = NSHostingController(rootView: view)
        configureTransparentLockScreenWindow(window)
        configureOverlayWindow(window)
        SkyLightOperator.shared.delegateWindow(window)

        lockScreenWindowController = NSWindowController(window: window)
        window.orderFrontRegardless()
    }

    private func configureTransparentLockScreenWindow(_ window: NSWindow?) {
        guard let window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func scheduleLockScreenWindowCloseAfterUnlock() {
        lockScreenWindowCloseTask?.cancel()

        lockScreenWindowCloseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(190))
            guard !Task.isCancelled else { return }
            guard let self,
                  self.environment.lockScreenOverlayModel.state == .music,
                  let screen = self.screenForCurrentDisplay() else {
                return
            }

            self.currentScreen = screen
            self.environment.lockScreenOverlayModel.isArtworkExpanded = false
            self.environment.lockScreenWallpaperManager.restore()
            self.lockScreenWindowController?.close()
            self.lockScreenWindowController = nil
            self.showIslandWindow(on: screen)
            self.updateFullscreenMonitoring()
            self.lockScreenWindowCloseTask = nil
        }
    }

    private func updateFullscreenMonitoring() {
        let shouldMonitor = environment.settingsManager.hideNotchWhenFullscreen &&
            environment.lockScreenOverlayModel.state == .music

        guard shouldMonitor else {
            fullscreenRefreshTask?.cancel()
            fullscreenRefreshTask = nil
            uninstallFullscreenObservers()

            if let screen = currentScreen ?? targetScreen() {
                setIslandHiddenForFullscreen(false, on: screen)
            }
            return
        }

        installFullscreenObserversIfNeeded()
        scheduleFullscreenVisibilityRefresh()
    }

    private func evaluateFullscreenVisibility() {
        guard environment.settingsManager.hideNotchWhenFullscreen,
              environment.lockScreenOverlayModel.state == .music,
              let screen = currentScreen ?? targetScreen() else {
            return
        }

        setIslandHiddenForFullscreen(isFullscreenAppActive(on: screen), on: screen)
    }

    private func installFullscreenObserversIfNeeded() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        if workspaceActivationObserver == nil {
            workspaceActivationObserver = workspaceCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.scheduleFullscreenVisibilityRefresh()
                }
            }
        }

        if activeSpaceObserver == nil {
            activeSpaceObserver = workspaceCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.scheduleFullscreenVisibilityRefresh()
                }
            }
        }
    }

    private func uninstallFullscreenObservers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        if let workspaceActivationObserver {
            workspaceCenter.removeObserver(workspaceActivationObserver)
            self.workspaceActivationObserver = nil
        }

        if let activeSpaceObserver {
            workspaceCenter.removeObserver(activeSpaceObserver)
            self.activeSpaceObserver = nil
        }
    }

    private func scheduleFullscreenVisibilityRefresh() {
        fullscreenRefreshTask?.cancel()

        // Debounce expensive CGWindowList queries so the overlay only reevaluates
        // fullscreen visibility when macOS app/space state actually changes.
        fullscreenRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            self?.evaluateFullscreenVisibility()
            self?.fullscreenRefreshTask = nil
        }
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
            lockScreenOverlayModel: environment.lockScreenOverlayModel,
            animationsEnabled: true,
            onClosedHeightChange: { [weak self] height in
                guard self?.environment.lockScreenOverlayModel.state == .music else { return }
                self?.currentClosedHeight = height
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        window.contentViewController = NSHostingController(rootView: view)
        SkyLightOperator.shared.delegateWindow(window)

        return NSWindowController(window: window)
    }

    private func updateIslandWindowFrame(on screen: NSScreen) {
        guard let window = islandWindowController?.window else { return }

        let nextFrame = islandWindowFrame(for: screen, size: islandWindowSize)
        guard !framesMatchOnBackingGrid(
            window.frame,
            nextFrame,
            scale: screen.backingScaleFactor
        ) else {
            return
        }

        window.setFrame(nextFrame, display: true)
    }

    private var islandWindowSize: CGSize {
        CGSize(width: 456, height: 280)
    }

    private func lockScreenPlayerYPosition(for screen: NSScreen) -> CGFloat {
        min(max(screen.frame.height * 0.68, 500), screen.frame.height - 130)
    }

    private func lockScreenArtworkSize(for screen: NSScreen) -> CGFloat {
        let playerTop = lockScreenPlayerYPosition(for: screen) - 77
        let clockSafeArea = max(150, screen.frame.height * 0.25)
        let availableHeight = max(playerTop - clockSafeArea - 18, 220)
        let sizeForScreen = min(screen.frame.width * 0.34, screen.frame.height * 0.42)
        return min(sizeForScreen, availableHeight, 540)
    }

    private func lockScreenWindowFrame(for screen: NSScreen) -> NSRect {
        let playerYPosition = lockScreenPlayerYPosition(for: screen)
        let artworkSize = lockScreenArtworkSize(for: screen)
        let expandedPlayerShift: CGFloat = 18
        let playerScale: CGFloat = 1.10
        let playerWidth: CGFloat = 339 * playerScale
        let playerHeight: CGFloat = 154 * playerScale
        let lowerPlayerOffset = playerHeight * 0.10
        let displayedArtworkSize = (artworkSize + expandedPlayerShift) * 1.05
        let expandedCompositionOffset = displayedArtworkSize * 0.10
        let maximumPlayerYPosition = playerYPosition + lowerPlayerOffset +
            expandedCompositionOffset + expandedPlayerShift
        let verticalPadding: CGFloat = 32
        let requiredHeight = maximumPlayerYPosition + playerHeight / 2 + verticalPadding
        let height = min(screen.frame.height, max(280, requiredHeight))
        let width = max(
            displayedArtworkSize + 48,
            playerWidth + 32,
            islandWindowSize.width,
            CGFloat(environment.settingsManager.islandWidth) + 40
        )

        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
        return alignedToBackingPixelGrid(frame, scale: screen.backingScaleFactor)
    }

    private func islandWindowFrame(for screen: NSScreen, size: CGSize) -> NSRect {
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        return alignedToBackingPixelGrid(frame, scale: screen.backingScaleFactor)
    }

    private func alignedToBackingPixel(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
    }

    private func alignedToBackingPixelGrid(_ frame: NSRect, scale: CGFloat) -> NSRect {
        let scale = max(scale, 1)
        let minX = alignedToBackingPixel(frame.minX, scale: scale)
        let maxX = alignedToBackingPixel(frame.maxX, scale: scale)
        let minY = alignedToBackingPixel(frame.minY, scale: scale)
        let maxY = alignedToBackingPixel(frame.maxY, scale: scale)

        return NSRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private func framesMatchOnBackingGrid(
        _ lhs: NSRect,
        _ rhs: NSRect,
        scale: CGFloat
    ) -> Bool {
        alignedToBackingPixelGrid(lhs, scale: scale) ==
            alignedToBackingPixelGrid(rhs, scale: scale)
    }

    private func screenForCurrentDisplay() -> NSScreen? {
        if let currentScreenID,
           let matchingScreen = NSScreen.screens.first(where: {
               displayID(for: $0) == currentScreenID
           }) {
            return matchingScreen
        }

        return targetScreen()
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
