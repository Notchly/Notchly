//
//  GeneralSettingsView.swift
//  Notchly
//
//  Created by user on 01.04.2026.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var codexHookIntegrationManager: CodexHookIntegrationManager
    @State private var isAccessibilityTrusted = AccessibilityPermissionManager.isTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsCard {
                VStack(spacing: 0) {
                    DisplayTargetPicker(
                        selection: $settingsManager.displayTarget
                    )

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Island Width")
                                    .font(.system(size: 13, weight: .medium))

                                Text("Set the base width used by the dynamic island.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(Int(settingsManager.islandWidth))px")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: $settingsManager.islandWidth,
                            in: 280...360,
                            step: 2
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    SettingsDivider()

                    SettingsToggleRow(
                        title: "Launch at Login",
                        subtitle: "Open Notchly automatically when you sign in.",
                        isOn: $settingsManager.launchAtLogin
                    )

                    SettingsDivider()

                    AccessibilityPermissionRow(
                        isTrusted: isAccessibilityTrusted,
                        requestAccess: requestAccessibilityAccess,
                        refreshStatus: refreshAccessibilityStatus
                    )

                    SettingsDivider()

                    CodexHookIntegrationRow(
                        manager: codexHookIntegrationManager
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
        .onAppear(perform: refreshAccessibilityStatus)
        .onAppear(perform: codexHookIntegrationManager.refreshStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
            codexHookIntegrationManager.refreshStatus()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func requestAccessibilityAccess() {
        AccessibilityPermissionManager.requestAccess()
        AccessibilityPermissionManager.openSystemSettings()
        refreshAccessibilityStatus()
    }

    private func refreshAccessibilityStatus() {
        isAccessibilityTrusted = AccessibilityPermissionManager.isTrusted
    }
}

private struct CodexHookIntegrationRow: View {
    @ObservedObject var manager: CodexHookIntegrationManager
    @State private var isPreviewVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Codex Alerts")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(statusText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(statusColor.opacity(0.16))
                            .clipShape(Capsule())
                    }

                    Text(descriptionText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 16)

                Button {
                    isPreviewVisible.toggle()
                } label: {
                    Text(isPreviewVisible ? "Hide Details" : "Show Details")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SubtleHoverButtonStyle(
                    pressedScale: 0.96,
                    hoverScale: 1.025,
                    hoverBackgroundOpacity: 0.08,
                    cornerRadius: 16
                ))

                Button {
                    manager.install()
                } label: {
                    Text(manager.isInstalled ? "Reinstall" : "Install Hook")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(manager.isInstalled ? Color.white.opacity(0.08) : Color.accentColor.opacity(0.26))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SubtleHoverButtonStyle(
                    pressedScale: 0.96,
                    hoverScale: 1.025,
                    hoverBackgroundOpacity: 0.08,
                    cornerRadius: 16
                ))
            }

            if isPreviewVisible {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notchly only adds this local Codex Stop hook. It writes a completion event file and does not read prompts or responses.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(manager.configPreview)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.82))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private var statusText: String {
        switch manager.installState {
        case .unknown:
            return "Checking"
        case .installed:
            return "Enabled"
        case .notInstalled:
            return "Not configured"
        case .failed:
            return "Failed"
        }
    }

    private var statusColor: Color {
        switch manager.installState {
        case .installed:
            return .green
        case .failed:
            return .red
        case .unknown:
            return .secondary
        case .notInstalled:
            return .orange
        }
    }

    private var descriptionText: String {
        if case let .failed(message) = manager.installState {
            return message
        }

        return "Shows Codex completion alerts using a transparent local Stop hook."
    }
}

private struct AccessibilityPermissionRow: View {
    let isTrusted: Bool
    let requestAccess: () -> Void
    let refreshStatus: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Accessibility Access")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(isTrusted ? "Enabled" : "Required")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isTrusted ? .green : .orange)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background((isTrusted ? Color.green : Color.orange).opacity(0.16))
                        .clipShape(Capsule())
                }

                Text("Required for ChatGPT notifications in hybrid mode.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            Button {
                requestAccess()
                refreshStatus()
            } label: {
                Text(isTrusted ? "Open Settings" : "Enable")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(isTrusted ? Color.white.opacity(0.08) : Color.accentColor.opacity(0.26))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(SubtleHoverButtonStyle(
                pressedScale: 0.96,
                hoverScale: 1.025,
                hoverBackgroundOpacity: 0.08,
                cornerRadius: 16
            ))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
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
