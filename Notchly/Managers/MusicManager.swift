//
//  MusicManager.swift
//  Notchly
//
//  Created by user on 16.03.2026.
//

import Foundation
import AppKit
import SwiftUI
import MediaRemoteAdapter
import Combine
import CoreAudio
import ScriptingBridge

enum MusicSource: String {
    case spotify = "Spotify"
    case appleMusic = "Music"
    case system = "Now Playing"
    case none = "None"
}

final class MusicManager: ObservableObject {
    @MainActor @Published private(set) var isPlaying: Bool = false
    @MainActor @Published private(set) var trackTitle: String = ""
    @MainActor @Published private(set) var artistName: String = ""
    @MainActor @Published private(set) var albumTitle: String = ""
    @MainActor @Published private(set) var artworkAvailable: Bool = false
    @MainActor @Published private(set) var playbackPosition: Double = 0
    @MainActor @Published private(set) var durationMs: Double = 0
    @MainActor @Published private(set) var sourceName: String = ""
    @MainActor @Published private(set) var currentSource: MusicSource = .none
    @MainActor @Published private(set) var artworkImage: NSImage?
    @MainActor @Published private(set) var waveformColor: Color = .white
    @MainActor @Published private(set) var outputVolume: Double = 0.5
    @MainActor @Published private(set) var isOutputMuted: Bool = false
    @MainActor @Published private(set) var outputVolumeEventID = 0
    @MainActor @Published private(set) var isShuffleEnabled: Bool = false

    @MainActor var hasNowPlayingContent: Bool {
        currentSource != .none && (!trackTitle.isEmpty || !artistName.isEmpty || !albumTitle.isEmpty)
    }

    @MainActor var isShuffleControlAvailable: Bool {
        currentSource == .spotify || currentSource == .appleMusic
    }

    nonisolated private let mediaController = MediaController()
    private var progressTask: Task<Void, Never>?
    private var volumePollTimer: Timer?

    private var basePlaybackPosition: Double = 0
    private var baseSyncDate: Date?
    private var currentPlaybackRate: Double = 0
    private var isPreviewSeeking = false
    private var currentTrackIdentity: String = ""
    private var lastAudibleOutputVolume: Double = 0.5
    private var ignoreTransientZeroProgressUntil: Date?
    private var pendingShuffleState: Bool?
    private var pendingShuffleStateUntil: Date?

    private let progressTickInterval: TimeInterval = 1.0
    private let volumePollInterval: TimeInterval = 0.22

    init() {
        bindMediaController()

        let mediaController = mediaController
        Task.detached(priority: .utility) {
            mediaController.startListening()
        }

        Task {
            await bootstrapNowPlaying()
        }

        Task { @MainActor in
            refreshOutputVolume(emitsEvent: false)
            startVolumePolling()
        }
    }

    deinit {
        progressTask?.cancel()
        progressTask = nil
        volumePollTimer?.invalidate()
        volumePollTimer = nil
        mediaController.stopListening()
    }

    private func bootstrapNowPlaying() async {
        for attempt in 0..<5 {
            let gotTrack = await fetchTrackInfoOnce()
            if gotTrack { return }

            let delayMs: UInt64 = min(UInt64(500) * UInt64(1 << attempt), 4000)
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
        }
    }

    private func fetchTrackInfoOnce() async -> Bool {
        await withCheckedContinuation { continuation in
            mediaController.getTrackInfo { [weak self] trackInfo in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                Task { @MainActor in
                    guard let trackInfo else {
                        continuation.resume(returning: false)
                        return
                    }

                    let payload = trackInfo.payload
                    let hasUsefulData =
                        !(payload.title ?? "").isEmpty ||
                        !(payload.artist ?? "").isEmpty ||
                        !(payload.album ?? "").isEmpty ||
                        !(payload.bundleIdentifier ?? "").isEmpty

                    if hasUsefulData {
                        self.apply(trackInfo)
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    private func bindMediaController() {
        mediaController.onTrackInfoReceived = { [weak self] trackInfo in
            guard let self, let trackInfo else { return }

            Task { @MainActor in
                self.apply(trackInfo)
            }
        }

        mediaController.onListenerTerminated = { [weak self] in
            guard let self else { return }

            Task { @MainActor in
                self.clearPlaybackState()
            }
        }
    }

    @MainActor
    private func apply(_ trackInfo: TrackInfo) {
        let payload = trackInfo.payload

        let newTrackTitle = payload.title ?? ""
        let newArtistName = payload.artist ?? ""
        let newAlbumTitle = payload.album ?? ""

        let playing = payload.isPlaying ?? ((payload.playbackRate ?? 0) > 0)
        let durationMicros = payload.durationMicros ?? 0
        let reportedDurationMs = durationMicros / 1000.0

        let reportedElapsedMs = payload.currentElapsedTime.map { $0 * 1000.0 }

        let bundleIdentifier = payload.bundleIdentifier ?? ""
        let newSourceName = payload.applicationName ?? prettySourceName(from: bundleIdentifier)
        let newSource = mapSource(from: bundleIdentifier)

        let newTrackIdentity = [
            newTrackTitle,
            newArtistName,
            newAlbumTitle,
            bundleIdentifier
        ].joined(separator: "|")

        let trackChanged = newTrackIdentity != currentTrackIdentity
        let shouldPreservePlaybackProgress = shouldPreservePlaybackProgressAfterShuffle(
            reportedElapsedMs: reportedElapsedMs,
            reportedDurationMs: reportedDurationMs,
            newTrackTitle: newTrackTitle,
            newArtistName: newArtistName
        )
        let newDurationMs = shouldPreservePlaybackProgress ? max(durationMs, reportedDurationMs) : reportedDurationMs
        let elapsedMs = shouldPreservePlaybackProgress ? estimatedPlaybackPositionMs() : (reportedElapsedMs ?? 0)

        currentTrackIdentity = newTrackIdentity

        trackTitle = newTrackTitle
        artistName = newArtistName
        albumTitle = newAlbumTitle
        isPlaying = playing
        durationMs = newDurationMs
        isShuffleEnabled = isShuffleAvailable(for: newSource)
            ? resolvedShuffleEnabled((payload.shuffleMode ?? .off) != .off)
            : false

        basePlaybackPosition = elapsedMs
        baseSyncDate = Date()
        currentPlaybackRate = payload.playbackRate ?? (playing ? 1.0 : 0.0)

        if !isPreviewSeeking {
            playbackPosition = elapsedMs
        }

        sourceName = newSourceName
        currentSource = newSource

        if trackChanged {
            updateArtwork(from: payload.artwork)
        } else if payload.artwork == nil && artworkImage != nil {
            updateArtwork(from: nil)
        }

        syncProgressTimerState()
    }

    @MainActor
    private func updateArtwork(from artwork: NSImage?) {
        guard let artwork else {
            artworkImage = nil
            artworkAvailable = false
            waveformColor = .white
            return
        }

        let preparedArtwork = artwork.resizedForArtwork()
        artworkImage = preparedArtwork
        artworkAvailable = true

        if let avgColor = preparedArtwork.averageColor?.boostedForWaveform {
            waveformColor = Color(nsColor: avgColor)
        } else {
            waveformColor = .white
        }
    }

    @MainActor
    private func startProgressTimerIfNeeded() {
        guard progressTask == nil else { return }
        guard isPlaying, durationMs > 0 else { return }

        let tickInterval = progressTickInterval

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickInterval))
                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    self?.tickProgress()
                }
            }
        }
    }

    @MainActor
    private func stopProgressTimer() {
        progressTask?.cancel()
        progressTask = nil
    }

    @MainActor
    private func syncProgressTimerState() {
        if isPlaying && durationMs > 0 {
            startProgressTimerIfNeeded()
        } else {
            stopProgressTimer()
        }
    }

    @MainActor
    func openCurrentPlayerApp() {
        let bundleIDs = candidatePlayerBundleIDs(for: sourceName)
        let workspace = NSWorkspace.shared

        for bundleID in bundleIDs {
            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                runningApp.activate()
                return
            }
        }

        let configuration = NSWorkspace.OpenConfiguration()

        for bundleID in bundleIDs {
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
                return
            }
        }
    }

    private func candidatePlayerBundleIDs(for sourceName: String) -> [String] {
        let source = sourceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch source {
        case "spotify":
            return ["com.spotify.client"]

        case "music", "apple music":
            return ["com.apple.Music"]

        case "google chrome", "chrome":
            return ["com.google.Chrome"]

        case "safari":
            return ["com.apple.Safari"]

        case "brave":
            return ["com.brave.Browser"]

        case "firefox":
            return ["org.mozilla.firefox"]

        case "microsoft edge", "edge":
            return ["com.microsoft.edgemac"]

        case "youtube", "youtube music", "yt music", "soundcloud", "deezer", "tidal":
            return [
                "com.google.Chrome",
                "com.apple.Safari",
                "com.brave.Browser",
                "org.mozilla.firefox",
                "com.microsoft.edgemac"
            ]

        default:
            return [
                "com.google.Chrome",
                "com.apple.Safari",
                "com.brave.Browser",
                "org.mozilla.firefox",
                "com.microsoft.edgemac",
                "com.spotify.client",
                "com.apple.Music"
            ]
        }
    }

    func togglePlay() {
        mediaController.togglePlayPause()
    }

    func nextTrack() {
        mediaController.nextTrack()
    }

    func previousTrack() {
        mediaController.previousTrack()
    }

    @MainActor
    func toggleShuffle(
        allowSpotifyAppleScript: Bool,
        allowAppleMusicAppleScript: Bool
    ) {
        guard isShuffleControlAvailable else {
            return
        }

        let wasShuffleEnabled = isShuffleEnabled
        let shouldEnableShuffle = !(pendingShuffleState ?? isShuffleEnabled)

        isShuffleEnabled = shouldEnableShuffle
        pendingShuffleState = shouldEnableShuffle
        pendingShuffleStateUntil = Date().addingTimeInterval(4.0)
        ignoreTransientZeroProgressUntil = Date().addingTimeInterval(6.0)

        switch currentSource {
        case .spotify where allowSpotifyAppleScript:
            if !setSpotifyShuffleEnabled(shouldEnableShuffle) {
                isShuffleEnabled = wasShuffleEnabled
                pendingShuffleState = nil
                pendingShuffleStateUntil = nil
                ignoreTransientZeroProgressUntil = nil
            } else {
                ignoreTransientZeroProgressUntil = Date().addingTimeInterval(6.0)
            }

        case .appleMusic where allowAppleMusicAppleScript:
            if !setAppleMusicShuffleEnabled(shouldEnableShuffle) {
                isShuffleEnabled = wasShuffleEnabled
                pendingShuffleState = nil
                pendingShuffleStateUntil = nil
                ignoreTransientZeroProgressUntil = nil
            } else {
                ignoreTransientZeroProgressUntil = Date().addingTimeInterval(6.0)
            }

        case .spotify, .appleMusic:
            mediaController.setShuffleMode(shouldEnableShuffle ? .songs : .off)

        default:
            break
        }
    }

    @MainActor
    func setOutputVolume(_ volume: Double) {
        let clamped = min(max(volume, 0), 1)

        guard SystemOutputVolume.setVolume(clamped) else {
            outputVolume = clamped
            isOutputMuted = clamped <= 0.01
            if clamped > 0.01 {
                lastAudibleOutputVolume = clamped
            }
            return
        }

        if clamped > 0.01 {
            lastAudibleOutputVolume = clamped
            _ = SystemOutputVolume.setMuted(false)
        }

        refreshOutputVolume(emitsEvent: false)
    }

    @MainActor
    func toggleOutputMute() {
        if isOutputMuted || outputVolume <= 0.01 {
            _ = SystemOutputVolume.setMuted(false)
            setOutputVolume(max(lastAudibleOutputVolume, 0.12))
        } else if !SystemOutputVolume.setMuted(true) {
            setOutputVolume(0)
        }

        refreshOutputVolume(emitsEvent: false)
    }

    @MainActor
    func previewSeek(toProgress progress: Double) {
        guard durationMs > 0 else { return }

        let clamped = min(max(progress, 0), 1)
        let targetMs = durationMs * clamped

        isPreviewSeeking = true
        playbackPosition = targetMs
    }

    @MainActor
    func seek(toProgress progress: Double) {
        guard durationMs > 0 else { return }

        let clamped = min(max(progress, 0), 1)
        let targetMs = durationMs * clamped
        let targetSeconds = targetMs / 1000.0

        mediaController.setTime(seconds: targetSeconds)

        playbackPosition = targetMs
        basePlaybackPosition = targetMs
        baseSyncDate = Date()
        isPreviewSeeking = false
    }

    @MainActor
    private func tickProgress() {
        guard isPlaying, durationMs > 0, !isPreviewSeeking else {
            stopProgressTimer()
            return
        }

        guard let baseSyncDate else { return }

        let elapsedSinceSync = Date().timeIntervalSince(baseSyncDate) * 1000.0
        let delta = elapsedSinceSync * currentPlaybackRate
        let newPosition = min(max(basePlaybackPosition + delta, 0), durationMs)

        playbackPosition = newPosition
    }

    @MainActor
    private func startVolumePolling() {
        guard volumePollTimer == nil else { return }

        volumePollTimer = Timer.scheduledTimer(withTimeInterval: volumePollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshOutputVolume(emitsEvent: true)
            }
        }

        if let volumePollTimer {
            RunLoop.main.add(volumePollTimer, forMode: .common)
        }
    }

    @MainActor
    private func refreshOutputVolume(emitsEvent: Bool) {
        let previousDisplayVolume = isOutputMuted ? 0 : outputVolume
        let previousMuted = isOutputMuted
        var nextVolume = outputVolume

        if let currentVolume = SystemOutputVolume.currentVolume() {
            nextVolume = currentVolume

            if currentVolume > 0.01 {
                lastAudibleOutputVolume = currentVolume
            }
        }

        let muted = SystemOutputVolume.isMuted() ?? false
        let nextMuted = muted || nextVolume <= 0.01

        let currentDisplayVolume = nextMuted ? 0 : nextVolume
        let volumeChanged = abs(currentDisplayVolume - previousDisplayVolume) >= 0.01
        let muteChanged = previousMuted != nextMuted

        if abs(outputVolume - nextVolume) >= 0.001 {
            outputVolume = nextVolume
        }

        if isOutputMuted != nextMuted {
            isOutputMuted = nextMuted
        }

        if emitsEvent && (volumeChanged || muteChanged) {
            outputVolumeEventID += 1
        }
    }

    @MainActor
    private func clearPlaybackState() {
        isPlaying = false
        trackTitle = ""
        artistName = ""
        albumTitle = ""
        playbackPosition = 0
        durationMs = 0
        sourceName = ""
        currentSource = .none
        artworkAvailable = false
        artworkImage = nil
        waveformColor = .white
        basePlaybackPosition = 0
        baseSyncDate = nil
        currentPlaybackRate = 0
        isPreviewSeeking = false
        currentTrackIdentity = ""
        isShuffleEnabled = false
        ignoreTransientZeroProgressUntil = nil
        pendingShuffleState = nil
        pendingShuffleStateUntil = nil

        stopProgressTimer()
    }

    @MainActor
    private func shouldPreservePlaybackProgressAfterShuffle(
        reportedElapsedMs: Double?,
        reportedDurationMs: Double,
        newTrackTitle: String,
        newArtistName: String
    ) -> Bool {
        guard let ignoreUntil = ignoreTransientZeroProgressUntil else { return false }

        if Date() > ignoreUntil {
            ignoreTransientZeroProgressUntil = nil
            return false
        }

        let estimatedPosition = estimatedPlaybackPositionMs()
        guard estimatedPosition > 1000, durationMs > 0 else {
            return false
        }

        let reportedPosition = reportedElapsedMs ?? 0
        let incomingLooksLikeReset = reportedPosition <= 1500 || reportedDurationMs <= 0
        let incomingMovesBackward = reportedPosition < estimatedPosition - 500
        guard incomingLooksLikeReset || incomingMovesBackward else { return false }

        let titleMatchesOrMissing =
            newTrackTitle.isEmpty ||
            trackTitle.isEmpty ||
            newTrackTitle == trackTitle
        let artistMatchesOrMissing =
            newArtistName.isEmpty ||
            artistName.isEmpty ||
            newArtistName == artistName

        return titleMatchesOrMissing && artistMatchesOrMissing
    }

    @MainActor
    private func estimatedPlaybackPositionMs() -> Double {
        guard isPlaying, durationMs > 0, let baseSyncDate else {
            return playbackPosition
        }

        let elapsedSinceSync = Date().timeIntervalSince(baseSyncDate) * 1000.0
        let delta = elapsedSinceSync * currentPlaybackRate
        return min(max(basePlaybackPosition + delta, playbackPosition), durationMs)
    }

    @MainActor
    private func resolvedShuffleEnabled(_ reportedShuffleEnabled: Bool) -> Bool {
        guard let pendingShuffleState, let pendingUntil = pendingShuffleStateUntil else {
            return reportedShuffleEnabled
        }

        if Date() > pendingUntil || reportedShuffleEnabled == pendingShuffleState {
            self.pendingShuffleState = nil
            pendingShuffleStateUntil = nil
            return reportedShuffleEnabled
        }

        return pendingShuffleState
    }

    private func mapSource(from bundleIdentifier: String) -> MusicSource {
        switch bundleIdentifier {
        case "com.spotify.client":
            return .spotify
        case "com.apple.Music":
            return .appleMusic
        case "":
            return .none
        default:
            return .system
        }
    }

    private func isShuffleAvailable(for source: MusicSource) -> Bool {
        source == .spotify || source == .appleMusic
    }

    private func prettySourceName(from bundleIdentifier: String) -> String {
        switch bundleIdentifier {
        case "com.spotify.client":
            return "Spotify"
        case "com.apple.Music":
            return "Music"
        case "":
            return ""
        default:
            return "Now Playing"
        }
    }

    @discardableResult
    private func setSpotifyShuffleEnabled(_ enabled: Bool) -> Bool {
        setScriptableApplicationBoolean(
            bundleIdentifier: "com.spotify.client",
            key: "shuffling",
            setter: "setShuffling:",
            enabled: enabled
        )
    }

    @discardableResult
    private func setAppleMusicShuffleEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            let didSetShuffleMode = setScriptableApplicationEnum(
                bundleIdentifier: "com.apple.Music",
                key: "shuffleMode",
                setter: "setShuffleMode:",
                value: fourCharacterCode("kShS")
            )

            guard didSetShuffleMode else {
                return false
            }
        }

        return setScriptableApplicationBoolean(
            bundleIdentifier: "com.apple.Music",
            key: "shuffleEnabled",
            setter: "setShuffleEnabled:",
            enabled: enabled
        )
    }

    private func setScriptableApplicationBoolean(
        bundleIdentifier: String,
        key: String,
        setter: String,
        enabled: Bool
    ) -> Bool {
        setScriptableApplicationValue(
            bundleIdentifier: bundleIdentifier,
            key: key,
            setter: setter,
            value: NSNumber(value: enabled)
        )
    }

    private func setScriptableApplicationEnum(
        bundleIdentifier: String,
        key: String,
        setter: String,
        value: OSType
    ) -> Bool {
        setScriptableApplicationValue(
            bundleIdentifier: bundleIdentifier,
            key: key,
            setter: setter,
            value: NSNumber(value: value)
        )
    }

    private func setScriptableApplicationValue(
        bundleIdentifier: String,
        key: String,
        setter: String,
        value: NSNumber
    ) -> Bool {
        guard let application = SBApplication(bundleIdentifier: bundleIdentifier) else {
            return false
        }

        application.timeout = 3
        guard application.responds(to: NSSelectorFromString(setter)) else {
            return false
        }

        application.setValue(value, forKey: key)
        return application.lastError() == nil
    }

    private func fourCharacterCode(_ string: String) -> OSType {
        string.utf8.prefix(4).reduce(OSType(0)) { result, byte in
            (result << 8) + OSType(byte)
        }
    }

}

private enum SystemOutputVolume {
    private static let outputScope = AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput)
    private static let mainElement = AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
    private static let leftElement = AudioObjectPropertyElement(1)
    private static let rightElement = AudioObjectPropertyElement(2)

    static func currentVolume() -> Double? {
        guard let deviceID = defaultOutputDeviceID() else { return nil }

        if let mainVolume = scalarValue(
            deviceID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            element: mainElement
        ) {
            return Double(mainVolume)
        }

        let channelVolumes = [leftElement, rightElement].compactMap {
            scalarValue(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar, element: $0)
        }

        guard !channelVolumes.isEmpty else { return nil }
        let average = channelVolumes.reduce(Float32(0), +) / Float32(channelVolumes.count)
        return Double(average)
    }

    static func setVolume(_ volume: Double) -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }

        let clamped = Float32(min(max(volume, 0), 1))

        if setScalarValue(
            clamped,
            deviceID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            element: mainElement
        ) {
            return true
        }

        let leftSet = setScalarValue(
            clamped,
            deviceID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            element: leftElement
        )
        let rightSet = setScalarValue(
            clamped,
            deviceID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            element: rightElement
        )

        return leftSet || rightSet
    }

    static func isMuted() -> Bool? {
        guard let deviceID = defaultOutputDeviceID() else { return nil }

        if let mainMuted = integerValue(
            deviceID: deviceID,
            selector: kAudioDevicePropertyMute,
            element: mainElement
        ) {
            return mainMuted != 0
        }

        let channelMuted = [leftElement, rightElement].compactMap {
            integerValue(deviceID: deviceID, selector: kAudioDevicePropertyMute, element: $0)
        }

        guard !channelMuted.isEmpty else { return nil }
        return channelMuted.allSatisfy { $0 != 0 }
    }

    static func setMuted(_ muted: Bool) -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }

        let value: UInt32 = muted ? 1 : 0

        if setIntegerValue(
            value,
            deviceID: deviceID,
            selector: kAudioDevicePropertyMute,
            element: mainElement
        ) {
            return true
        }

        let leftSet = setIntegerValue(
            value,
            deviceID: deviceID,
            selector: kAudioDevicePropertyMute,
            element: leftElement
        )
        let rightSet = setIntegerValue(
            value,
            deviceID: deviceID,
            selector: kAudioDevicePropertyMute,
            element: rightElement
        )

        return leftSet || rightSet
    }

    private static func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: mainElement
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != AudioDeviceID(kAudioObjectUnknown) else {
            return nil
        }

        return deviceID
    }

    private static func scalarValue(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> Float32? {
        var address = propertyAddress(selector: selector, element: element)
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)

        guard status == noErr else { return nil }
        return min(max(value, 0), 1)
    }

    private static func setScalarValue(
        _ value: Float32,
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> Bool {
        var address = propertyAddress(selector: selector, element: element)
        guard isSettable(deviceID: deviceID, address: &address) else { return false }

        var mutableValue = value
        let size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &mutableValue)

        return status == noErr
    }

    private static func integerValue(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> UInt32? {
        var address = propertyAddress(selector: selector, element: element)
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)

        guard status == noErr else { return nil }
        return value
    }

    private static func setIntegerValue(
        _ value: UInt32,
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> Bool {
        var address = propertyAddress(selector: selector, element: element)
        guard isSettable(deviceID: deviceID, address: &address) else { return false }

        var mutableValue = value
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &mutableValue)

        return status == noErr
    }

    private static func isSettable(
        deviceID: AudioDeviceID,
        address: inout AudioObjectPropertyAddress
    ) -> Bool {
        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var isSettable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)

        return status == noErr && isSettable.boolValue
    }

    private static func propertyAddress(
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: outputScope,
            mElement: element
        )
    }
}
