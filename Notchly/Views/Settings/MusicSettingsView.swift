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
        Form {
            Section {
                Toggle("Sound", isOn: $settingsManager.showMusic)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Preview Duration")
                        Spacer()
                        Text("\(settingsManager.musicPreviewDuration, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $settingsManager.musicPreviewDuration,
                        in: 1...3,
                        step: 0.5
                    )
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Controls how long the music preview appears when a track starts, changes, or is skipped.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
