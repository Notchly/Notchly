//
//  BatterySettingsView.swift
//  Notchly
//
//  Created by user on 01.04.2026.
//

import SwiftUI

struct BatterySettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        Form {
            Section {
                Toggle("Show Battery", isOn: $settingsManager.showBattery)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Low Battery Threshold")
                        Spacer()
                        Text("\(settingsManager.lowBatteryThreshold)%")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(settingsManager.lowBatteryThreshold) },
                            set: { settingsManager.lowBatteryThreshold = Int($0) }
                        ),
                        in: 5...50,
                        step: 5
                    )
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Controls when the low battery state should appear.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
