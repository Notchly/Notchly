//
//  IslandContainerView.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI

struct IslandContainerView<Content: View>: View {
    let size: CGSize
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let shadowOpacity: Double
    let showsTopCornerCutouts: Bool
    let content: Content

    init(
        size: CGSize,
        cornerRadius: CGFloat,
        spacing: CGFloat,
        shadowOpacity: Double = 0,
        showsTopCornerCutouts: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.shadowOpacity = shadowOpacity
        self.showsTopCornerCutouts = showsTopCornerCutouts
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            IslandBackgroundView(
                size: size,
                cornerRadius: cornerRadius,
                spacing: spacing,
                shadowOpacity: shadowOpacity,
                showsTopCornerCutouts: showsTopCornerCutouts
            )

            content
        }
    }
}
