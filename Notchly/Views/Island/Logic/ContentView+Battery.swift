//
//  ContentView+Battery.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI

extension ContentView {
    var emptyBar: some View {
        EmptyIslandView(
            size: layout.closedSize,
            cornerRadius: layout.cornerRadius,
            spacing: layout.spacing,
            isHovered: isHovered
        )
    }

    var islandContainer: some View {
        IslandContainerView(
            size: layout.islandSize,
            cornerRadius: layout.cornerRadius,
            spacing: layout.spacing,
            shadowOpacity: status == .opened || status == .popping ? 0.2 : 0
        ) {
            if status == .closed {
                CompactBatteryView(
                    batteryLevel: batteryManager.batteryLevel,
                    symbolName: batterySymbolName,
                    iconColor: closedIconColor,
                    textColor: closedTextColor,
                    size: layout.closedSize,
                    hoverOffsetY: hoverOffsetY
                )
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(1)
            }

            if showChargingPop && status != .opened {
                ChargingPopView(
                    batteryLevel: batteryManager.batteryLevel,
                    symbolName: batterySymbolName,
                    size: layout.chargingSize
                )
                .offset(y: 1)
                .allowsHitTesting(false)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(2)
            }

            if status == .opened {
                ExpandedBatteryView(
                    batteryLevel: batteryManager.batteryLevel,
                    isCharging: batteryManager.isCharging,
                    symbolName: batterySymbolName,
                    progressColor: progressColor,
                    stateText: stateText,
                    size: layout.openedSize
                )
                .offset(y: 20)
                .allowsHitTesting(false)
                .transition(
                    .scale(scale: 0.9)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: -20))
                )
                .zIndex(3)
            }
        }
        .onTapGesture {
            guard settingsManager.showBattery else { return }

            autoExpandMusicTask?.cancel()

            withAnimation(animation) {
                status = (status == .opened) ? .closed : .opened
            }
        }
    }

    func handleBatteryVisibilityChange(_ isEnabled: Bool) {
        guard !isEnabled else { return }

        showChargingPop = false

        guard dynamicManager.currentModule != .music else { return }
        guard status == .opened || status == .popping else { return }

        withAnimation(animation) {
            status = .closed
        }
    }

    func handleChargingChange(_ newValue: Bool) {
        guard settingsManager.showBattery else {
            showChargingPop = false
            return
        }
        guard dynamicManager.currentModule == .battery else { return }
        guard hasFinishedInitialAppear else { return }
        guard status == .closed else { return }

        if newValue {
            status = .popping

            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                showChargingPop = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                guard settingsManager.showBattery else { return }
                guard status != .opened else { return }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                    showChargingPop = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    guard settingsManager.showBattery else { return }
                    withAnimation(animation) {
                        status = .closed
                    }
                }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                showChargingPop = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                guard settingsManager.showBattery else { return }
                withAnimation(animation) {
                    status = .closed
                }
            }
        }
    }
}
