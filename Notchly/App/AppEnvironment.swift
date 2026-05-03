//
//  AppEnvironment.swift
//  Notchly
//
//  Created by user on 03.05.2026.
//

import Sparkle

@MainActor
final class AppEnvironment {
    let musicManager = MusicManager()
    let settingsManager = SettingsManager()
    let lockScreenOverlayModel = LockScreenOverlayModel()

    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    lazy var batteryManager = BatteryManager(musicManager: musicManager)

    lazy var dynamicManager = DynamicManager(
        batteryManager: batteryManager,
        musicManager: musicManager,
        settingsManager: settingsManager
    )

    lazy var settingsWindow = SettingsWindow(
        settingsManager: settingsManager
    )
}
