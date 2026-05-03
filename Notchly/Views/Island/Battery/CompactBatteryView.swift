//
//  CompactBatteryView.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI

struct CompactBatteryView: View {
    let batteryLevel: Int
    let symbolName: String
    let iconColor: Color
    let textColor: Color
    let size: CGSize
    let hoverOffsetY: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)

            Spacer()

            Text("\(batteryLevel)%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(width: size.width, height: size.height)
        .offset(y: hoverOffsetY)
    }
}
