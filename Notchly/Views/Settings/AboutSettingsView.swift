//
//  AboutSettingsView.swift
//  Notchly
//
//  Created by user on 29.04.2026.
//

//
//  AboutSettingsView.swift
//  Notchly
//

import SwiftUI

struct AboutSettingsView: View {
    @Environment(\.openURL) private var openURL

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let version, let build {
            return "Version \(version) (\(build))"
        }

        if let version {
            return "Version \(version)"
        }

        return "Version unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            heroCard

            SettingsCard {
                VStack(spacing: 0) {
                    AboutLinkRow(
                        icon: "globe",
                        title: "Website",
                        subtitle: "Open the Notchly website.",
                        hoverBorderEdge: .top
                    ) {
                        open("https://notchly.xyz")
                    }

                    SettingsDivider()

                    AboutLinkRow(
                        icon: "envelope.fill",
                        title: "Contact",
                        subtitle: "Send feedback or report an issue.",
                        hoverBorderEdge: .bottom
                    ) {
                        open("mailto:hello@notchly.app")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 5)

            VStack(spacing: 4) {
                Text("Notchly")
                    .font(.system(size: 22, weight: .bold))

                Text("Turn your MacBook notch into a useful, interactive space.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(appVersionText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func open(_ value: String) {
        guard let url = URL(string: value) else { return }
        openURL(url)
    }
}

private struct AboutLinkRow: View {
    enum HoverBorderEdge {
        case top
        case bottom
    }

    let icon: String
    let title: String
    let subtitle: String
    let hoverBorderEdge: HoverBorderEdge
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.10))

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .background(.white.opacity(isHovered ? 0.045 : 0))
            .overlay {
                VStack(spacing: 0) {
                    if hoverBorderEdge == .bottom {
                        Spacer(minLength: 0)
                    }

                    Rectangle()
                        .fill(.white.opacity(isHovered ? 0.12 : 0))
                        .frame(height: 1)

                    if hoverBorderEdge == .top {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.006 : 1)
        .onHover { hovering in
            withAnimation(.interactiveSpring(duration: 0.18, extraBounce: 0.06)) {
                isHovered = hovering
            }
        }
    }
}
