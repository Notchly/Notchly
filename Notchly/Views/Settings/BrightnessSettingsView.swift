//
//  BrightnessSettingsView.swift
//  Notchly
//
//  Created by n0xbyte on 23.05.2026.
//

import SwiftUI

struct BrightnessSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Brightness",
                        subtitle: "Show a small island status when display brightness changes.",
                        isOn: $settingsManager.showBrightnessStatus
                    )

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Brightness Line",
                        subtitle: "Show the brightness progress line next to the percentage.",
                        isOn: $settingsManager.showBrightnessLine
                    )
                    .disabled(!settingsManager.showBrightnessStatus)
                    .opacity(settingsManager.showBrightnessStatus ? 1 : 0.45)

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Line Width")
                                    .font(.system(size: 13, weight: .medium))

                                Text("Adjust how much room the brightness line uses.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(Int(settingsManager.brightnessLineWidth))px")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: $settingsManager.brightnessLineWidth,
                            in: 20...40,
                            step: 2
                        )
                        .disabled(!settingsManager.showBrightnessStatus || !settingsManager.showBrightnessLine)
                        .opacity(settingsManager.showBrightnessStatus && settingsManager.showBrightnessLine ? 1 : 0.45)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Show Percent",
                        subtitle: "Show the numeric brightness value on the right.",
                        isOn: $settingsManager.showBrightnessPercent
                    )
                    .disabled(!settingsManager.showBrightnessStatus)
                    .opacity(settingsManager.showBrightnessStatus ? 1 : 0.45)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
