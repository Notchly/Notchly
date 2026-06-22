//
//  BatterySettingsView.swift
//  Notchly
//
//  Created by n0xbyte on 01.04.2026.
//

import SwiftUI

struct BatterySettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Show Battery Island",
                        subtitle: "Display battery state and charging updates around the notch.",
                        isOn: $settingsManager.showBattery
                    )

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Low Battery Threshold")
                                    .font(.system(size: 13, weight: .medium))

                                Text("Choose when Notchly should show the low battery state.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(settingsManager.lowBatteryThreshold)%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settingsManager.lowBatteryThreshold) },
                                set: { settingsManager.lowBatteryThreshold = Int($0) }
                            ),
                            in: 5...50,
                            step: 5
                        )
                        .disabled(!settingsManager.showBattery)
                        .opacity(settingsManager.showBattery ? 1 : 0.45)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }

            Text("Controls when the low battery state appears while Battery Island is enabled.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
