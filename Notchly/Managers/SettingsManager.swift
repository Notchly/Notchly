//
//  SettingsManager.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import Foundation
import Combine
import ServiceManagement

@MainActor
final class SettingsManager: ObservableObject {
    private enum Defaults {
        static let showBattery = true
        static let showMusic = true
        static let showOnPrimaryDisplayOnly = true
        static let lowBatteryThreshold = 20
        static let musicPreviewDuration = 2.0
        static let enableSpotifyAppleScriptControl = false
        static let enableAppleMusicAppleScriptControl = false
        static let launchAtLogin = false
        static let enableLockSound = true
        static let showFocusAnimations = true
    }

    @Published var showBattery: Bool {
        didSet { UserDefaults.standard.set(showBattery, forKey: "showBattery") }
    }

    @Published var showMusic: Bool {
        didSet { UserDefaults.standard.set(showMusic, forKey: "showMusic") }
    }

    @Published var showOnPrimaryDisplayOnly: Bool {
        didSet { UserDefaults.standard.set(showOnPrimaryDisplayOnly, forKey: "showOnPrimaryDisplayOnly") }
    }

    @Published var lowBatteryThreshold: Int {
        didSet { UserDefaults.standard.set(lowBatteryThreshold, forKey: "lowBatteryThreshold") }
    }
    
    @Published var musicPreviewDuration: Double {
        didSet { UserDefaults.standard.set(musicPreviewDuration, forKey: "musicPreviewDuration") }
    }

    @Published var enableSpotifyAppleScriptControl: Bool {
        didSet { UserDefaults.standard.set(enableSpotifyAppleScriptControl, forKey: "enableSpotifyAppleScriptControl") }
    }

    @Published var enableAppleMusicAppleScriptControl: Bool {
        didSet { UserDefaults.standard.set(enableAppleMusicAppleScriptControl, forKey: "enableAppleMusicAppleScriptControl") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin(launchAtLogin)
        }
    }
    
    @Published var enableLockSound: Bool {
        didSet { UserDefaults.standard.set(enableLockSound, forKey: "enableLockSound") }
    }

    @Published var showFocusAnimations: Bool {
        didSet { UserDefaults.standard.set(showFocusAnimations, forKey: "showFocusAnimations") }
    }

    init() {
        self.showBattery = UserDefaults.standard.object(forKey: "showBattery") as? Bool ?? Defaults.showBattery
        self.showMusic = UserDefaults.standard.object(forKey: "showMusic") as? Bool ?? Defaults.showMusic
        self.showOnPrimaryDisplayOnly = UserDefaults.standard.object(forKey: "showOnPrimaryDisplayOnly") as? Bool ?? Defaults.showOnPrimaryDisplayOnly
        self.lowBatteryThreshold = UserDefaults.standard.object(forKey: "lowBatteryThreshold") as? Int ?? Defaults.lowBatteryThreshold
        self.musicPreviewDuration = UserDefaults.standard.object(forKey: "musicPreviewDuration") as? Double ?? Defaults.musicPreviewDuration
        self.enableSpotifyAppleScriptControl = UserDefaults.standard.object(forKey: "enableSpotifyAppleScriptControl") as? Bool ?? Defaults.enableSpotifyAppleScriptControl
        self.enableAppleMusicAppleScriptControl = UserDefaults.standard.object(forKey: "enableAppleMusicAppleScriptControl") as? Bool ?? Defaults.enableAppleMusicAppleScriptControl

        let savedLaunchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool
        let systemLaunchAtLogin = SMAppService.mainApp.status == .enabled
        self.launchAtLogin = savedLaunchAtLogin ?? systemLaunchAtLogin
        self.enableLockSound = UserDefaults.standard.object(forKey: "enableLockSound") as? Bool ?? Defaults.enableLockSound
        self.showFocusAnimations = UserDefaults.standard.object(forKey: "showFocusAnimations") as? Bool ?? Defaults.showFocusAnimations
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func resetGeneralSettings() {
        showOnPrimaryDisplayOnly = Defaults.showOnPrimaryDisplayOnly
        launchAtLogin = Defaults.launchAtLogin
        enableLockSound = Defaults.enableLockSound
        showFocusAnimations = Defaults.showFocusAnimations
    }

    func resetBatterySettings() {
        showBattery = Defaults.showBattery
        lowBatteryThreshold = Defaults.lowBatteryThreshold
    }

    func resetMusicSettings() {
        showMusic = Defaults.showMusic
        musicPreviewDuration = Defaults.musicPreviewDuration
        enableSpotifyAppleScriptControl = Defaults.enableSpotifyAppleScriptControl
        enableAppleMusicAppleScriptControl = Defaults.enableAppleMusicAppleScriptControl
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let actual = SMAppService.mainApp.status == .enabled
            if launchAtLogin != actual {
                launchAtLogin = actual
            }
        }
    }
}
