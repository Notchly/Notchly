//
//  DynamicManager.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import Foundation
import Combine

@MainActor
final class DynamicManager: ObservableObject {
    @Published var currentModule: IslandModule = .none

    let batteryManager: BatteryManager
    let musicManager: MusicManager
    let settingsManager: SettingsManager

    private var cancellables = Set<AnyCancellable>()

    init(
        batteryManager: BatteryManager,
        musicManager: MusicManager,
        settingsManager: SettingsManager
    ) {
        self.batteryManager = batteryManager
        self.musicManager = musicManager
        self.settingsManager = settingsManager

        bind()
        updateCurrentModule()
    }

    private func bind() {
        batteryManager.$batteryLevel
            .combineLatest(batteryManager.$isCharging)
            .map { _ in () }
            .sink { [weak self] in self?.updateCurrentModule() }
            .store(in: &cancellables)
        
        musicManager.$isPlaying
            .combineLatest(
                musicManager.$trackTitle,
                musicManager.$currentSource,
                musicManager.$isResolvingNowPlaying
            )
            .map { _ in () }
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] in self?.updateCurrentModule() }
            .store(in: &cancellables)

        settingsManager.$showBattery
            .combineLatest(settingsManager.$showMusic)
            .map { _ in () }
            .sink { [weak self] in self?.updateCurrentModule() }
            .store(in: &cancellables)
    }

    func updateCurrentModule() {
        let newModule: IslandModule

        if settingsManager.showMusic && musicManager.hasNowPlayingContent {
            newModule = .music
        } else if settingsManager.showMusic && musicManager.isResolvingNowPlaying {
            newModule = .none
        } else if settingsManager.showBattery {
            newModule = .battery
        } else {
            newModule = .none
        }

        guard newModule != currentModule else { return }
        currentModule = newModule
    }
}
