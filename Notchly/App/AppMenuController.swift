//
//  AppMenuController.swift
//  Notchly
//
//  Created by n0xbyte on 03.05.2026.
//

import AppKit
import Sparkle

@MainActor
final class AppMenuController: NSObject {
    private var statusItem: NSStatusItem?
    private var hasStartedUpdater = false

    private let settingsWindow: SettingsWindow
    private let whatsNewWindow: WhatsNewWindow
    private let updaterController: SPUStandardUpdaterController
    private let agentEventManager: AgentEventManager

    init(
        settingsWindow: SettingsWindow,
        whatsNewWindow: WhatsNewWindow,
        updaterController: SPUStandardUpdaterController,
        agentEventManager: AgentEventManager
    ) {
        self.settingsWindow = settingsWindow
        self.whatsNewWindow = whatsNewWindow
        self.updaterController = updaterController
        self.agentEventManager = agentEventManager
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            button.image = image
        }

        item.menu = makeMenu()
        startUpdaterIfNeeded()
    }

    private func makeMenu() -> NSMenu {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        let versionItem = NSMenuItem(
            title: "Version \(appVersion)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        let updatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updatesItem.target = self

        let whatsNewItem = NSMenuItem(
            title: "What's New...",
            action: #selector(openWhatsNew),
            keyEquivalent: ""
        )
        whatsNewItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self

        let menu = NSMenu()
        menu.addItem(versionItem)
        menu.addItem(settingsItem)

#if DEBUG
        let testCodexItem = NSMenuItem(
            title: "Test Codex Alert",
            action: #selector(testCodexAlert),
            keyEquivalent: ""
        )
        testCodexItem.target = self
        menu.addItem(testCodexItem)

        let testCursorItem = NSMenuItem(
            title: "Test Cursor Alert",
            action: #selector(testCursorAlert),
            keyEquivalent: ""
        )
        testCursorItem.target = self
        menu.addItem(testCursorItem)

        let testWhatsNewItem = NSMenuItem(
            title: "Test What's New Update",
            action: #selector(testWhatsNewUpdate),
            keyEquivalent: ""
        )
        testWhatsNewItem.target = self
        menu.addItem(testWhatsNewItem)
#endif

        menu.addItem(.separator())
        menu.addItem(whatsNewItem)
        menu.addItem(updatesItem)
        menu.addItem(quitItem)
        return menu
    }

#if DEBUG
    @objc private func testCodexAlert() {
        agentEventManager.publish(
            source: "codex",
            kind: .accessRequest,
            title: "Need approval",
            message: "Test alert from menu",
            ttl: 3.0
        )
    }

    @objc private func testCursorAlert() {
        agentEventManager.publish(
            source: "cursor",
            kind: .accessRequest,
            title: "Need approval",
            message: "Test Cursor alert from menu",
            ttl: 3.0
        )
    }

    @objc private func testWhatsNewUpdate() {
        whatsNewWindow.simulateUpdateForTesting()
    }
#endif

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func openWhatsNew() {
        whatsNewWindow.show()
    }

    @objc private func checkForUpdates() {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        startUpdaterIfNeeded()

        updaterController.checkForUpdates(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func startUpdaterIfNeeded() {
        guard !hasStartedUpdater else { return }
        updaterController.startUpdater()
        hasStartedUpdater = true
    }
}
