//
//  GeneralSettingsView.swift
//  Notchly
//
//  Created by user on 01.04.2026.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Primary Display Only",
                        subtitle: "Show Notchly only on your primary display.",
                        isOn: $settingsManager.showOnPrimaryDisplayOnly
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Launch at Login",
                        subtitle: "Open Notchly automatically when you sign in.",
                        isOn: $settingsManager.launchAtLogin
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Lock Sound",
                        subtitle: "Play a subtle sound when the lock screen state changes.",
                        isOn: $settingsManager.enableLockSound
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Focus Animations",
                        subtitle: "Show a small island animation when Focus turns on or off.",
                        isOn: $settingsManager.showFocusAnimations
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
