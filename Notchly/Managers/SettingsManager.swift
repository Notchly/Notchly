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
        didSet {UserDefaults.standard.set(musicPreviewDuration, forKey: "musicPreviewDuration")}
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

    init() {
        self.showBattery = UserDefaults.standard.object(forKey: "showBattery") as? Bool ?? true
        self.showMusic = UserDefaults.standard.object(forKey: "showMusic") as? Bool ?? true
        self.showOnPrimaryDisplayOnly = UserDefaults.standard.object(forKey: "showOnPrimaryDisplayOnly") as? Bool ?? true
        self.lowBatteryThreshold = UserDefaults.standard.object(forKey: "lowBatteryThreshold") as? Int ?? 20
        self.musicPreviewDuration = UserDefaults.standard.object(forKey: "musicPreviewDuration") as? Double ?? 2

        let savedLaunchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool
        let systemLaunchAtLogin = SMAppService.mainApp.status == .enabled
        self.launchAtLogin = savedLaunchAtLogin ?? systemLaunchAtLogin
        self.enableLockSound = UserDefaults.standard.object(forKey: "enableLockSound") as? Bool ?? true
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("LaunchAtLogin error:", error.localizedDescription)

            let actual = SMAppService.mainApp.status == .enabled
            if launchAtLogin != actual {
                launchAtLogin = actual
            }
        }
    }
}
