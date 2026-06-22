//
//  EmptyIslandView.swift
//  Notchly
//
//  Created by n0xbyte on 25.03.2026.
//

import SwiftUI

struct EmptyIslandView: View {
    let size: CGSize
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let isHovered: Bool

    var body: some View {
        Rectangle()
            .foregroundStyle(.black)
            .mask(
                IslandMaskView(
                    size: size,
                    cornerRadius: cornerRadius,
                    spacing: spacing
                )
            )
            .frame(
                width: size.width + cornerRadius * 2,
                height: size.height
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(isHovered ? 0.09 : 0.04), lineWidth: 1)
                    .frame(width: size.width, height: size.height)
            }
            .shadow(color: .black.opacity(0.12), radius: 12)
    }
}
