//
//  SettingsSidebarIconView.swift
//  Notchly
//
//  Created by user on 01.04.2026.
//

import SwiftUI

struct SettingsSidebarIconView: View {
    let systemName: String
    let backgroundColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            backgroundColor.opacity(0.95),
                            backgroundColor.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )

            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 24, height: 24)
    }
}
