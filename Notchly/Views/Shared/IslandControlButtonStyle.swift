//
//  IslandControlButtonStyle.swift
//  Notchly
//
//  Created by user on 24.03.2026.
//

import SwiftUI

struct IslandControlButtonStyle: ButtonStyle {
    let pressedScale: CGFloat

    init(pressedScale: CGFloat = 0.92) {
        self.pressedScale = pressedScale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.interactiveSpring(duration: 0.18, extraBounce: 0.08), value: configuration.isPressed)
    }
}
