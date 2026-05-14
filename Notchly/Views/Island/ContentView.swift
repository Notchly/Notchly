//
//  ContentView.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var batteryManager: BatteryManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var dynamicManager: DynamicManager
    @ObservedObject var musicManager: MusicManager
    let animationsEnabled: Bool

    @State var status: IslandStatus = .closed
    @State var showChargingPop = false
    @State var isHovered = false
    @State var hasFinishedInitialAppear = false
    @State var autoExpandMusicTask: Task<Void, Never>?
    @State var lastMusicAutoOpenKey: String = ""
    @State var previewAutoCloseKey: String = ""
    @State var musicScrollGestureState: Int = 0
    @State var isPointerInsideIsland = false
    @State var playPauseBounce = false
    @State var skipIndicator: String?
    @State var showMusicVolumeControl = false
    @State var currentScreen: NSScreen?
    @State var resolvedClosedHeight: CGFloat = 36
    
    private func updateClosedHeight(for screen: NSScreen?) {
        resolvedClosedHeight = IslandHeightResolver.closedHeight(for: screen)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .allowsHitTesting(false)

            activeModuleView
                .padding(.top, 0)
                .zIndex(10)
                .scaleEffect(hoverScale)
                .onHover { hovering in
                    handleHover(hovering)
                }
                .animation(.easeInOut(duration: 0.22), value: settingsManager.showBattery)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            handleAppear()
        }
        .onChange(of: batteryManager.isCharging) { _, newValue in
            handleChargingChange(newValue)
        }
        .onChange(of: currentMusicAutoOpenKey) { _, _ in
            handleMusicAutoExpand(isPlaying: musicManager.isPlaying)
        }
        .onChange(of: status) { _, newValue in
            guard newValue != .opened else { return }
            showMusicVolumeControl = false
        }
        .animation(.interactiveSpring(duration: 0.32, extraBounce: 0.03), value: isHovered)
        .animation(animation, value: status)
        .animation(animation, value: showMusicVolumeControl)
        .animation(.easeInOut(duration: 0.22), value: batteryManager.batteryLevel)
        .preferredColorScheme(.dark)
        .background(
            WindowScreenReader { screen in
                guard currentScreen !== screen else { return }
                currentScreen = screen
                updateClosedHeight(for: screen)
            }
        )
    }
}
