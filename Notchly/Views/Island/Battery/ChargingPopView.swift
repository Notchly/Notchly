//
//  ChargingPopView.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI

struct ChargingPopView: View {
    let batteryLevel: Int
    let symbolName: String
    let size: CGSize

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))

                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .offset(y: 0.5)
            }

            Text("\(batteryLevel)%")
                .font(.system(size: 13, weight: .semibold))

            Text("Charging")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .frame(width: size.width, height: size.height)
    }
}
