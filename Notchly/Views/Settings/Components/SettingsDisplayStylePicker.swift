//
//  SettingsDisplayStylePicker.swift
//  Notchly
//
//  Created by n0xbyte on 22.06.2026.
//

import SwiftUI

struct SettingsDisplayStylePicker: View {
    let title: String
    let subtitle: String
    @Binding var selection: StatusDisplayStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                SettingsDisplayStyleOption(
                    title: "Line",
                    subtitle: "Compact bar",
                    symbolName: "line.horizontal.preview",
                    isSelected: selection == .line
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection = .line
                    }
                }

                SettingsDisplayStyleOption(
                    title: "Percent",
                    subtitle: "Numeric value",
                    symbolName: "number",
                    isSelected: selection == .percent
                ) {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection = .percent
                    }
                }
            }
        }
    }
}

private struct SettingsDisplayStyleOption: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.08))
                    .frame(width: 42, height: 42)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color.accentColor.opacity(0.62) : Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .overlay {
                        optionIcon
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white, Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 58)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.black.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(SubtleHoverButtonStyle(
            pressedScale: 0.97,
            hoverScale: 1.012,
            hoverBackgroundOpacity: 0.06,
            cornerRadius: 10
        ))
    }

    @ViewBuilder
    private var optionIcon: some View {
        if symbolName == "line.horizontal.preview" {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill((isSelected ? Color.white : Color.secondary).opacity(0.28))
                    .frame(width: 20, height: 4)

                Capsule()
                    .fill(isSelected ? Color.white : Color.secondary)
                    .frame(width: 12, height: 4)
            }
        } else {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
        }
    }
}
