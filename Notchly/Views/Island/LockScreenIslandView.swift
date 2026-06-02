//
//  LockScreenIslandView.swift
//  Notchly
//
//  Created by user on 01.04.2026.
//

import SwiftUI

struct LockScreenIslandView: View {
    private let cornerRadius: CGFloat = 8

    let islandWidth: CGFloat
    let height: CGFloat
    let isUnlocking: Bool
    let showOpenedLock: Bool

    private var islandSize: CGSize {
        CGSize(width: islandWidth, height: height)
    }

    var body: some View {
        IslandContainerView(
            size: islandSize,
            cornerRadius: cornerRadius,
            spacing: 0,
            shadowOpacity: 0.12
        ) {
            HStack(spacing: 8) {
                Image(systemName: showOpenedLock ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(width: islandSize.width, height: islandSize.height)
        }
        .frame(width: islandSize.width, height: islandSize.height)
        .fixedSize()
    }
}
