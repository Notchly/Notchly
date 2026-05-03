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

enum MusicSource: String {
    case spotify = "Spotify"
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

    @MainActor var hasNowPlayingContent: Bool {
        currentSource != .none && (!trackTitle.isEmpty || !artistName.isEmpty || !albumTitle.isEmpty)
    }

    nonisolated private let mediaController = MediaController()
    private var progressTimer: Timer?

    private var basePlaybackPosition: Double = 0
    private var baseSyncDate: Date?
    private var currentPlaybackRate: Double = 0
    private var isPreviewSeeking = false
    private var currentTrackIdentity: String = ""

    private let progressTickInterval: TimeInterval = 1.0

    init() {
        bindMediaController()

        let mediaController = mediaController
        Task.detached(priority: .utility) {
            mediaController.startListening()
        }

        Task {
            await bootstrapNowPlaying()
        }
    }

    deinit {
        progressTimer?.invalidate()
        progressTimer = nil
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
        let newDurationMs = durationMicros / 1000.0

        let elapsedSeconds = payload.currentElapsedTime ?? 0
        let elapsedMs = elapsedSeconds * 1000.0

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
        currentTrackIdentity = newTrackIdentity

        trackTitle = newTrackTitle
        artistName = newArtistName
        albumTitle = newAlbumTitle
        isPlaying = playing
        durationMs = newDurationMs

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

        artworkImage = artwork
        artworkAvailable = true

        if let avgColor = artwork.averageColor?.boostedForWaveform {
            waveformColor = Color(nsColor: avgColor)
        } else {
            waveformColor = .white
        }
    }

    @MainActor
    private func startProgressTimerIfNeeded() {
        guard progressTimer == nil else { return }
        guard isPlaying, durationMs > 0 else { return }

        progressTimer = Timer.scheduledTimer(withTimeInterval: progressTickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tickProgress()
            }
        }

        if let progressTimer {
            RunLoop.main.add(progressTimer, forMode: .common)
        }
    }

    @MainActor
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
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

    func togglePlay() async {
        mediaController.togglePlayPause()
    }

    func nextTrack() async {
        mediaController.nextTrack()
    }

    func previousTrack() async {
        mediaController.previousTrack()
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

        stopProgressTimer()
    }

    private func mapSource(from bundleIdentifier: String) -> MusicSource {
        switch bundleIdentifier {
        case "com.spotify.client":
            return .spotify
        case "":
            return .none
        default:
            return .system
        }
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
}
