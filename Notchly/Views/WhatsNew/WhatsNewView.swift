//
//  WhatsNewView.swift
//  Notchly
//
//  Created by n0xbyte on 19.07.2026.
//

import SwiftUI

struct WhatsNewView: View {
    let release: WhatsNewRelease
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            SettingsBackground()

            VStack(spacing: 0) {
                header

                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(release.features.enumerated()), id: \.element.id) { index, feature in
                            featureRow(feature)

                            if index < release.features.count - 1 {
                                Divider()
                                    .opacity(0.35)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .background(.black.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 36)

                Spacer(minLength: 20)

                Button("Continue", action: dismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(.bottom, 26)
            }
        }
        .frame(width: 560, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .ignoresSafeArea(.container, edges: .top)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 5) {
                Text("What's New in Notchly")
                    .font(.system(size: 27, weight: .bold, design: .rounded))

                Text("Version \(release.version)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 44)
        .padding(.bottom, 24)
    }

    private func featureRow(_ feature: WhatsNewRelease.Feature) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(feature.title)
                .font(.system(size: 15, weight: .semibold))

            Text(feature.description)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 13)
    }
}
