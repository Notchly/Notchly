//
//  ExpandedBatteryView.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI

struct ExpandedBatteryView: View {
    let batteryLevel: Int
    let isCharging: Bool
    let symbolName: String
    let progressColor: Color
    let stateText: String
    let size: CGSize

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Image(systemName: symbolName)
                            .font(.system(size: 20, weight: .semibold))

                        if isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }

                    Text("\(batteryLevel)%")
                        .font(.system(size: 18, weight: .bold))
                }

                Spacer()

                Text(stateText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(10, geo.size.width * CGFloat(batteryLevel) / 100))
                }
            }
            .frame(height: 10)

            HStack {
                Text(isCharging ? "Power connected" : "On battery")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(width: size.width, height: size.height, alignment: .top)
        .foregroundStyle(.white)
    }
}
