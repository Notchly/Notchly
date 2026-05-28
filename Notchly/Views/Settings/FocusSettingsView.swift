//
//  FocusSettingsView.swift
//  Notchly
//
//  Created by user on 23.05.2026.
//

import SwiftUI

struct FocusSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Focus",
                        subtitle: "Show a small island animation when Focus turns on or off.",
                        isOn: $settingsManager.showFocusAnimations
                    )

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Animation Duration")
                                    .font(.system(size: 13, weight: .medium))

                                Text("How long the Focus status stays visible.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(settingsManager.focusAnimationDuration, specifier: "%.1f")s")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: $settingsManager.focusAnimationDuration,
                            in: 0.8...4,
                            step: 0.2
                        )
                        .disabled(!settingsManager.showFocusAnimations)
                        .opacity(settingsManager.showFocusAnimations ? 1 : 0.45)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Hide Label",
                        subtitle: "Hide the On/Off label on the right side of the island.",
                        isOn: $settingsManager.hideFocusLabel
                    )
                    .disabled(!settingsManager.showFocusAnimations)
                    .opacity(settingsManager.showFocusAnimations ? 1 : 0.45)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
