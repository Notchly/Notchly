//
//  MusicSettingsView.swift
//  Notchly
//
//  Created by user on 01.04.2026.
//

import SwiftUI

struct MusicSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Music Preview",
                        subtitle: "Show the currently playing track around the notch.",
                        isOn: $settingsManager.showMusic
                    )

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Preview Duration")
                                    .font(.system(size: 13, weight: .medium))

                                Text("How long the preview stays visible after a track change.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(settingsManager.musicPreviewDuration, specifier: "%.1f")s")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: $settingsManager.musicPreviewDuration,
                            in: 1...3,
                            step: 0.5
                        )
                        .disabled(!settingsManager.showMusic)
                        .opacity(settingsManager.showMusic ? 1 : 0.45)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Spotify Shuffle Control",
                        subtitle: "Allow Notchly to toggle shuffle directly in Spotify.",
                        isOn: $settingsManager.enableSpotifyAppleScriptControl
                    )
                    .disabled(!settingsManager.showMusic)
                    .opacity(settingsManager.showMusic ? 1 : 0.45)

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Apple Music Shuffle Control",
                        subtitle: "Allow Notchly to toggle shuffle directly in Apple Music.",
                        isOn: $settingsManager.enableAppleMusicAppleScriptControl
                    )
                    .disabled(!settingsManager.showMusic)
                    .opacity(settingsManager.showMusic ? 1 : 0.45)
                }
            }

            Text("macOS may ask for Automation permission the first time Notchly controls Spotify or Apple Music.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
