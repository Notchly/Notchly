//
//  BrightnessSettingsView.swift
//  Notchly
//
//  Created by n0xbyte on 23.05.2026.
//

import SwiftUI

struct BrightnessSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var displayStyleBinding: Binding<StatusDisplayStyle> {
        Binding(
            get: { settingsManager.brightnessDisplayStyle },
            set: { settingsManager.brightnessDisplayStyle = $0 }
        )
    }

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

                    SettingsDisplayStylePicker(
                        title: "Display Style",
                        subtitle: "Choose either a compact line or a numeric percentage.",
                        selection: displayStyleBinding
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
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
                        .disabled(!settingsManager.showBrightnessStatus || settingsManager.brightnessDisplayStyle != .line)
                        .opacity(settingsManager.showBrightnessStatus && settingsManager.brightnessDisplayStyle == .line ? 1 : 0.45)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
