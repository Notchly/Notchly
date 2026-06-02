//
//  AppMenuController.swift
//  Notchly
//
//  Created by user on 03.05.2026.
//

import AppKit
import Sparkle

@MainActor
final class AppMenuController: NSObject {
    private var statusItem: NSStatusItem?
    private var hasStartedUpdater = false

    private let settingsWindow: SettingsWindow
    private let updaterController: SPUStandardUpdaterController
    private let agentEventManager: AgentEventManager

    init(
        settingsWindow: SettingsWindow,
        updaterController: SPUStandardUpdaterController,
        agentEventManager: AgentEventManager
    ) {
        self.settingsWindow = settingsWindow
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
#endif

        menu.addItem(.separator())
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
#endif

    @objc private func openSettings() {
        settingsWindow.show()
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
