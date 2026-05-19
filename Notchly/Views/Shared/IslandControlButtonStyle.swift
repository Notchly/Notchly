//
//  IslandControlButtonStyle.swift
//  Notchly
//
//  Created by user on 24.03.2026.
//

import SwiftUI

struct IslandControlButtonStyle: ButtonStyle {
    let pressedScale: CGFloat
    let hoverScale: CGFloat
    let hoverBackgroundOpacity: Double

    init(
        pressedScale: CGFloat = 0.92,
        hoverScale: CGFloat = 1.08,
        hoverBackgroundOpacity: Double = 0.09
    ) {
        self.pressedScale = pressedScale
        self.hoverScale = hoverScale
        self.hoverBackgroundOpacity = hoverBackgroundOpacity
    }

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(
            configuration: configuration,
            pressedScale: pressedScale,
            hoverScale: hoverScale,
            hoverBackgroundOpacity: hoverBackgroundOpacity,
            cornerRadius: 12
        )
    }
}

struct SubtleHoverButtonStyle: ButtonStyle {
    let pressedScale: CGFloat
    let hoverScale: CGFloat
    let hoverBackgroundOpacity: Double
    let cornerRadius: CGFloat

    init(
        pressedScale: CGFloat = 0.97,
        hoverScale: CGFloat = 1.012,
        hoverBackgroundOpacity: Double = 0.08,
        cornerRadius: CGFloat = 10
    ) {
        self.pressedScale = pressedScale
        self.hoverScale = hoverScale
        self.hoverBackgroundOpacity = hoverBackgroundOpacity
        self.cornerRadius = cornerRadius
    }

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(
            configuration: configuration,
            pressedScale: pressedScale,
            hoverScale: hoverScale,
            hoverBackgroundOpacity: hoverBackgroundOpacity,
            cornerRadius: cornerRadius
        )
    }
}

private struct HoverButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let pressedScale: CGFloat
    let hoverScale: CGFloat
    let hoverBackgroundOpacity: Double
    let cornerRadius: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var scale: CGFloat {
        if configuration.isPressed { return pressedScale }
        if isHovered && isEnabled { return hoverScale }
        return 1.0
    }

    private var backgroundOpacity: Double {
        if !isEnabled { return 0 }
        if configuration.isPressed { return hoverBackgroundOpacity * 1.35 }
        return isHovered ? hoverBackgroundOpacity : 0
    }

    var body: some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(backgroundOpacity))
            }
            .scaleEffect(scale)
            .opacity(isEnabled ? 1.0 : 0.5)
            .onHover { hovering in
                withAnimation(.interactiveSpring(duration: 0.18, extraBounce: 0.08)) {
                    isHovered = hovering
                }
            }
            .animation(.interactiveSpring(duration: 0.18, extraBounce: 0.08), value: configuration.isPressed)
            .animation(.interactiveSpring(duration: 0.18, extraBounce: 0.08), value: isEnabled)
    }
}
