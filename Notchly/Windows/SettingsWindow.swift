//
//  SettingsWindow.swift
//  Notchly
//
//  Created by n0xbyte on 16.03.2026.
//

import SwiftUI
import AppKit

final class SettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let settingsManager: SettingsManager
    private let codexHookIntegrationManager: CodexHookIntegrationManager
    private let cursorHookIntegrationManager: CursorHookIntegrationManager

    init(
        settingsManager: SettingsManager,
        codexHookIntegrationManager: CodexHookIntegrationManager,
        cursorHookIntegrationManager: CursorHookIntegrationManager
    ) {
        self.settingsManager = settingsManager
        self.codexHookIntegrationManager = codexHookIntegrationManager
        self.cursorHookIntegrationManager = cursorHookIntegrationManager
        super.init()
    }

    func show() {
        settingsManager.refreshLaunchAtLoginStatus()

        if let window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let rootView = SettingsView(
            settingsManager: settingsManager,
            codexHookIntegrationManager: codexHookIntegrationManager,
            cursorHookIntegrationManager: cursorHookIntegrationManager
        )
            .ignoresSafeArea(.container, edges: .top)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 680),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.delegate = self
        window.center()
        window.title = "Settings"
        window.isReleasedWhenClosed = false

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = nil

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = false

        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        window.contentView = NSHostingView(rootView: rootView)

        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
