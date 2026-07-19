//
//  WhatsNewWindow.swift
//  Notchly
//
//  Created by n0xbyte on 19.07.2026.
//

import AppKit
import SwiftUI

@MainActor
final class WhatsNewWindow: NSObject, NSWindowDelegate {
    private enum DefaultsKey {
        static let lastPresentedVersion = "lastPresentedWhatsNewVersion"
        static let sparkleHasLaunchedBefore = "SUHasLaunchedBefore"
    }

    private let defaults: UserDefaults
    private let wasExistingInstallAtLaunch: Bool
    private var window: NSWindow?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.wasExistingInstallAtLaunch = defaults.bool(
            forKey: DefaultsKey.sparkleHasLaunchedBefore
        )
        super.init()
    }

    func showIfNeeded() {
        showIfNeeded(allowVersionMismatch: false)
    }

    private func showIfNeeded(allowVersionMismatch: Bool) {
        let release = WhatsNewRelease.current
        let installedVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String

        guard allowVersionMismatch || installedVersion == release.version else {
            return
        }

        guard let lastPresentedVersion = defaults.string(
            forKey: DefaultsKey.lastPresentedVersion
        ) else {
            defaults.set(release.version, forKey: DefaultsKey.lastPresentedVersion)

            if wasExistingInstallAtLaunch {
                show()
            }

            return
        }

        guard release.version.compare(lastPresentedVersion, options: .numeric) == .orderedDescending else {
            return
        }

        defaults.set(release.version, forKey: DefaultsKey.lastPresentedVersion)
        show()
    }

    func show() {
        if let window {
            activateApp()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let rootView = WhatsNewView(release: .current) { [weak window] in
            window?.performClose(nil)
        }

        window.delegate = self
        window.center()
        window.title = "What's New in Notchly"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = nil
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(rootView: rootView)

        self.window = window

        activateApp()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

#if DEBUG
    func simulateUpdateForTesting() {
        defaults.set("0", forKey: DefaultsKey.lastPresentedVersion)
        showIfNeeded(allowVersionMismatch: true)
    }
#endif

    func windowWillClose(_ notification: Notification) {
        let closingWindow = notification.object as? NSWindow
        window = nil

        let hasOtherVisibleWindow = NSApp.windows.contains { candidate in
            candidate !== closingWindow && candidate.isVisible && candidate.level == .normal
        }

        if !hasOtherVisibleWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
