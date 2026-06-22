//
//  SoundSettingsView.swift
//  Notchly
//
//  Created by n0xbyte on 26.05.2026.
//

import SwiftUI

struct SoundSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    private var displayStyleBinding: Binding<StatusDisplayStyle> {
        Binding(
            get: { settingsManager.soundDisplayStyle },
            set: { settingsManager.soundDisplayStyle = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Sound",
                        subtitle: "Show a small island status when output volume changes.",
                        isOn: $settingsManager.showSoundStatus
                    )

                    SettingsDivider()

                    SettingsDisplayStylePicker(
                        title: "Display Style",
                        subtitle: "Choose either a compact line or a numeric percentage.",
                        selection: displayStyleBinding
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .disabled(!settingsManager.showSoundStatus)
                    .opacity(settingsManager.showSoundStatus ? 1 : 0.45)

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Line Width")
                                    .font(.system(size: 13, weight: .medium))

                                Text("Adjust how much room the sound line uses.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(Int(settingsManager.soundLineWidth))px")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: $settingsManager.soundLineWidth,
                            in: 20...40,
                            step: 2
                        )
                        .disabled(!settingsManager.showSoundStatus || settingsManager.soundDisplayStyle != .line)
                        .opacity(settingsManager.showSoundStatus && settingsManager.soundDisplayStyle == .line ? 1 : 0.45)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
