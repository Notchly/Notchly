//
//  BatteryManager.swift
//  Notchly
//
//  Created by n0xbyte on 16.03.2026.
//

import Foundation
import IOKit
import IOKit.ps
import Combine

final class BatteryManager: ObservableObject {
    @Published var batteryLevel: Int = 0
    @Published var isCharging: Bool = false
    @Published var isBatteryAvailable: Bool = true
    @Published var powerSource: String = "Unknown"

    private var timer: Timer?
    private let musicManager: MusicManager

    init(musicManager: MusicManager) {
        self.musicManager = musicManager

        updateBatteryInfo()
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    func startMonitoring() {
        timer?.invalidate()

        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            guard !self.shouldPauseBatteryUpdates else {
                return
            }

            self.updateBatteryInfo()
        }

        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private var shouldPauseBatteryUpdates: Bool {
        musicManager.hasNowPlayingContent
    }

    func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.isBatteryAvailable {
                    self.isBatteryAvailable = false
                }
                if self.powerSource != "Unknown" {
                    self.powerSource = "Unknown"
                }
            }
            return
        }

        let current = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let max = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
        let charging = description[kIOPSIsChargingKey as String] as? Bool ?? false
        let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String ?? ""
        let percent = max > 0 ? Int((Double(current) / Double(max)) * 100.0) : 0

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let nextIsCharging = charging || powerSourceState == kIOPSACPowerValue

            if self.batteryLevel != percent {
                self.batteryLevel = percent
            }
            if self.isCharging != nextIsCharging {
                self.isCharging = nextIsCharging
            }
            if !self.isBatteryAvailable {
                self.isBatteryAvailable = true
            }
            if self.powerSource != powerSourceState {
                self.powerSource = powerSourceState
            }
        }
    }
}
