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
                    DisplayTargetPicker(
                        selection: $settingsManager.displayTarget
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
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct DisplayTargetPicker: View {
    @Binding var selection: DisplayTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Display")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Choose where Notchly appears.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(DisplayTarget.allCases, id: \.self) { target in
                    DisplayTargetOption(
                        target: target,
                        isSelected: selection == target
                    ) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selection = target
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DisplayTargetOption: View {
    let target: DisplayTarget
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.08))
                        .frame(width: 54, height: 42)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? Color.accentColor.opacity(0.62) : Color.white.opacity(0.08), lineWidth: 1)
                        }

                    Image(systemName: target.symbolName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(width: 54, height: 42)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(target.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(target.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 62)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.black.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
