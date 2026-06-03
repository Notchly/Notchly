//
//  SettingsManager.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import Foundation
import Combine
import ServiceManagement

enum DisplayTarget: String, CaseIterable {
    case main
    case builtIn

    var title: String {
        switch self {
        case .main:
            return "Main display"
        case .builtIn:
            return "Built in display"
        }
    }

    var subtitle: String {
        switch self {
        case .main:
            return "Follow the active main screen."
        case .builtIn:
            return "Prefer the MacBook display."
        }
    }

    var symbolName: String {
        switch self {
        case .main:
            return "display"
        case .builtIn:
            return "laptopcomputer"
        }
    }
}

@MainActor
final class SettingsManager: ObservableObject {
    private enum Defaults {
        static let showBattery = true
        static let showMusic = true
        static let islandWidth = 318.0
        static let displayTarget = DisplayTarget.builtIn
        static let lowBatteryThreshold = 20
        static let musicPreviewDuration = 2.0
        static let enableSpotifyAppleScriptControl = false
        static let enableAppleMusicAppleScriptControl = false
        static let launchAtLogin = false
        static let enableLockSound = true
        static let hideNotchWhenFullscreen = false
        static let showFocusAnimations = true
        static let focusAnimationDuration = 2.0
        static let hideFocusLabel = false
        static let showBrightnessStatus = true
        static let showBrightnessLine = true
        static let brightnessLineWidth = 36.0
        static let showBrightnessPercent = true
        static let showSoundStatus = true
        static let showSoundLine = true
        static let soundLineWidth = 36.0
        static let showSoundPercent = true
        static let enableCodexApprovalAlertSound = false
        static let enableCodexCompletedAlertSound = false
        static let codexCompletedAlertDuration = 2.2
    }

    @Published var showBattery: Bool {
        didSet { UserDefaults.standard.set(showBattery, forKey: "showBattery") }
    }

    @Published var showMusic: Bool {
        didSet { UserDefaults.standard.set(showMusic, forKey: "showMusic") }
    }

    @Published var islandWidth: Double {
        didSet { UserDefaults.standard.set(islandWidth, forKey: "islandWidth") }
    }

    @Published var displayTarget: DisplayTarget {
        didSet { UserDefaults.standard.set(displayTarget.rawValue, forKey: "displayTarget") }
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

    @Published var hideNotchWhenFullscreen: Bool {
        didSet { UserDefaults.standard.set(hideNotchWhenFullscreen, forKey: "hideNotchWhenFullscreen") }
    }

    @Published var showFocusAnimations: Bool {
        didSet { UserDefaults.standard.set(showFocusAnimations, forKey: "showFocusAnimations") }
    }

    @Published var focusAnimationDuration: Double {
        didSet { UserDefaults.standard.set(focusAnimationDuration, forKey: "focusAnimationDuration") }
    }

    @Published var hideFocusLabel: Bool {
        didSet { UserDefaults.standard.set(hideFocusLabel, forKey: "hideFocusLabel") }
    }

    @Published var showBrightnessStatus: Bool {
        didSet { UserDefaults.standard.set(showBrightnessStatus, forKey: "showBrightnessStatus") }
    }

    @Published var showBrightnessLine: Bool {
        didSet { UserDefaults.standard.set(showBrightnessLine, forKey: "showBrightnessLine") }
    }

    @Published var brightnessLineWidth: Double {
        didSet { UserDefaults.standard.set(brightnessLineWidth, forKey: "brightnessLineWidth") }
    }

    @Published var showBrightnessPercent: Bool {
        didSet { UserDefaults.standard.set(showBrightnessPercent, forKey: "showBrightnessPercent") }
    }

    @Published var showSoundStatus: Bool {
        didSet { UserDefaults.standard.set(showSoundStatus, forKey: "showSoundStatus") }
    }

    @Published var showSoundLine: Bool {
        didSet { UserDefaults.standard.set(showSoundLine, forKey: "showSoundLine") }
    }

    @Published var soundLineWidth: Double {
        didSet { UserDefaults.standard.set(soundLineWidth, forKey: "soundLineWidth") }
    }

    @Published var showSoundPercent: Bool {
        didSet { UserDefaults.standard.set(showSoundPercent, forKey: "showSoundPercent") }
    }

    @Published var enableCodexApprovalAlertSound: Bool {
        didSet { UserDefaults.standard.set(enableCodexApprovalAlertSound, forKey: "enableCodexApprovalAlertSound") }
    }

    @Published var enableCodexCompletedAlertSound: Bool {
        didSet { UserDefaults.standard.set(enableCodexCompletedAlertSound, forKey: "enableCodexCompletedAlertSound") }
    }

    @Published var codexCompletedAlertDuration: Double {
        didSet { UserDefaults.standard.set(codexCompletedAlertDuration, forKey: "codexCompletedAlertDuration") }
    }

    init() {
        self.showBattery = UserDefaults.standard.object(forKey: "showBattery") as? Bool ?? Defaults.showBattery
        self.showMusic = UserDefaults.standard.object(forKey: "showMusic") as? Bool ?? Defaults.showMusic
        self.islandWidth = UserDefaults.standard.object(forKey: "islandWidth") as? Double ?? Defaults.islandWidth
        self.displayTarget = Self.loadDisplayTarget()
        self.lowBatteryThreshold = UserDefaults.standard.object(forKey: "lowBatteryThreshold") as? Int ?? Defaults.lowBatteryThreshold
        self.musicPreviewDuration = UserDefaults.standard.object(forKey: "musicPreviewDuration") as? Double ?? Defaults.musicPreviewDuration
        self.enableSpotifyAppleScriptControl = UserDefaults.standard.object(forKey: "enableSpotifyAppleScriptControl") as? Bool ?? Defaults.enableSpotifyAppleScriptControl
        self.enableAppleMusicAppleScriptControl = UserDefaults.standard.object(forKey: "enableAppleMusicAppleScriptControl") as? Bool ?? Defaults.enableAppleMusicAppleScriptControl

        let savedLaunchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool
        let systemLaunchAtLogin = SMAppService.mainApp.status == .enabled
        self.launchAtLogin = savedLaunchAtLogin ?? systemLaunchAtLogin
        self.enableLockSound = UserDefaults.standard.object(forKey: "enableLockSound") as? Bool ?? Defaults.enableLockSound
        self.hideNotchWhenFullscreen = UserDefaults.standard.object(forKey: "hideNotchWhenFullscreen") as? Bool ?? Defaults.hideNotchWhenFullscreen
        self.showFocusAnimations = UserDefaults.standard.object(forKey: "showFocusAnimations") as? Bool ?? Defaults.showFocusAnimations
        self.focusAnimationDuration = UserDefaults.standard.object(forKey: "focusAnimationDuration") as? Double ?? Defaults.focusAnimationDuration
        self.hideFocusLabel = UserDefaults.standard.object(forKey: "hideFocusLabel") as? Bool ?? Defaults.hideFocusLabel
        self.showBrightnessStatus = UserDefaults.standard.object(forKey: "showBrightnessStatus") as? Bool ?? Defaults.showBrightnessStatus
        self.showBrightnessLine = UserDefaults.standard.object(forKey: "showBrightnessLine") as? Bool ?? Defaults.showBrightnessLine
        self.brightnessLineWidth = UserDefaults.standard.object(forKey: "brightnessLineWidth") as? Double ?? Defaults.brightnessLineWidth
        self.showBrightnessPercent = UserDefaults.standard.object(forKey: "showBrightnessPercent") as? Bool ?? Defaults.showBrightnessPercent
        self.showSoundStatus = UserDefaults.standard.object(forKey: "showSoundStatus") as? Bool ?? Defaults.showSoundStatus
        self.showSoundLine = UserDefaults.standard.object(forKey: "showSoundLine") as? Bool ?? Defaults.showSoundLine
        self.soundLineWidth = UserDefaults.standard.object(forKey: "soundLineWidth") as? Double ?? Defaults.soundLineWidth
        self.showSoundPercent = UserDefaults.standard.object(forKey: "showSoundPercent") as? Bool ?? Defaults.showSoundPercent
        let legacyCodexAlertSound = UserDefaults.standard.object(forKey: "enableCodexAlertSound") as? Bool
        self.enableCodexApprovalAlertSound = UserDefaults.standard.object(forKey: "enableCodexApprovalAlertSound") as? Bool ?? legacyCodexAlertSound ?? Defaults.enableCodexApprovalAlertSound
        self.enableCodexCompletedAlertSound = UserDefaults.standard.object(forKey: "enableCodexCompletedAlertSound") as? Bool ?? legacyCodexAlertSound ?? Defaults.enableCodexCompletedAlertSound
        self.codexCompletedAlertDuration = UserDefaults.standard.object(forKey: "codexCompletedAlertDuration") as? Double ?? Defaults.codexCompletedAlertDuration
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func resetGeneralSettings() {
        islandWidth = Defaults.islandWidth
        displayTarget = Defaults.displayTarget
        launchAtLogin = Defaults.launchAtLogin
        enableLockSound = Defaults.enableLockSound
        hideNotchWhenFullscreen = Defaults.hideNotchWhenFullscreen
    }

    func resetFocusSettings() {
        showFocusAnimations = Defaults.showFocusAnimations
        focusAnimationDuration = Defaults.focusAnimationDuration
        hideFocusLabel = Defaults.hideFocusLabel
    }

    func resetBatterySettings() {
        showBattery = Defaults.showBattery
        lowBatteryThreshold = Defaults.lowBatteryThreshold
    }

    func resetBrightnessSettings() {
        showBrightnessStatus = Defaults.showBrightnessStatus
        showBrightnessLine = Defaults.showBrightnessLine
        brightnessLineWidth = Defaults.brightnessLineWidth
        showBrightnessPercent = Defaults.showBrightnessPercent
    }

    func resetSoundSettings() {
        showSoundStatus = Defaults.showSoundStatus
        showSoundLine = Defaults.showSoundLine
        soundLineWidth = Defaults.soundLineWidth
        showSoundPercent = Defaults.showSoundPercent
    }

    func resetMusicSettings() {
        showMusic = Defaults.showMusic
        musicPreviewDuration = Defaults.musicPreviewDuration
        enableSpotifyAppleScriptControl = Defaults.enableSpotifyAppleScriptControl
        enableAppleMusicAppleScriptControl = Defaults.enableAppleMusicAppleScriptControl
    }

    func resetCodexSettings() {
        enableCodexApprovalAlertSound = Defaults.enableCodexApprovalAlertSound
        enableCodexCompletedAlertSound = Defaults.enableCodexCompletedAlertSound
        codexCompletedAlertDuration = Defaults.codexCompletedAlertDuration
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

    private static func loadDisplayTarget() -> DisplayTarget {
        if let rawValue = UserDefaults.standard.string(forKey: "displayTarget"),
           let displayTarget = DisplayTarget(rawValue: rawValue) {
            return displayTarget
        }

        if let legacyPrimaryOnly = UserDefaults.standard.object(forKey: "showOnPrimaryDisplayOnly") as? Bool {
            return legacyPrimaryOnly ? .builtIn : .main
        }

        return Defaults.displayTarget
    }
}
