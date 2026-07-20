//
//  LockScreenIslandView.swift
//  Notchly
//
//  Created by n0xbyte on 01.04.2026.
//

import SwiftUI

struct LockScreenIslandView: View {
    private let cornerRadius: CGFloat = 8

    let islandWidth: CGFloat
    let height: CGFloat
    let showOpenedLock: Bool

    private var islandSize: CGSize {
        CGSize(width: islandWidth, height: height)
    }

    var body: some View {
        IslandContainerView(
            size: islandSize,
            cornerRadius: cornerRadius,
            spacing: 0,
            shadowOpacity: 0,
            showsTopCornerCutouts: false
        ) {
            HStack(spacing: 8) {
                ZStack {
                    Image(systemName: "lock.fill")
                        .opacity(showOpenedLock ? 0 : 1)

                    Image(systemName: "lock.open.fill")
                        .opacity(showOpenedLock ? 1 : 0)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: 14, height: 16)
                .animation(.easeOut(duration: 0.10), value: showOpenedLock)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(width: islandSize.width, height: islandSize.height)
        }
        .frame(width: islandSize.width, height: islandSize.height)
        .fixedSize()
    }
}
