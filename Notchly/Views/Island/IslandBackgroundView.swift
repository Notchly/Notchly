//
//  IslandBackgroundView.swift
//  Notchly
//
//  Created by n0xbyte on 25.03.2026.
//

import SwiftUI

struct IslandBackgroundView: View {
    let size: CGSize
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let shadowOpacity: Double
    let showsTopCornerCutouts: Bool

    var body: some View {
        Rectangle()
            .foregroundStyle(.black)
            .mask(
                IslandMaskView(
                    size: size,
                    cornerRadius: cornerRadius,
                    spacing: spacing,
                    showsTopCornerCutouts: showsTopCornerCutouts
                )
            )
            .frame(
                width: size.width + cornerRadius * 2,
                height: size.height
            )
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: 10,
                x: 0,
                y: -1
            )
    }
}
