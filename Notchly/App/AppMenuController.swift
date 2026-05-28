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
    private var scheduledUpdaterStartTask: Task<Void, Never>?

    private let settingsWindow: SettingsWindow
    private let updaterController: SPUStandardUpdaterController

    init(
        settingsWindow: SettingsWindow,
        updaterController: SPUStandardUpdaterController
    ) {
        self.settingsWindow = settingsWindow
        self.updaterController = updaterController
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
        scheduleUpdaterStart()
    }

    deinit {
        scheduledUpdaterStartTask?.cancel()
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
        menu.addItem(.separator())
        menu.addItem(updatesItem)
        menu.addItem(quitItem)
        return menu
    }

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

    private func scheduleUpdaterStart() {
        guard scheduledUpdaterStartTask == nil else { return }

        scheduledUpdaterStartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.startUpdaterIfNeeded()
            self?.scheduledUpdaterStartTask = nil
        }
    }

    private func startUpdaterIfNeeded() {
        guard !hasStartedUpdater else { return }
        updaterController.startUpdater()
        hasStartedUpdater = true
    }
}
