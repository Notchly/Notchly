//
//  LockScreenMusicView.swift
//  Notchly
//
//  Created by Codex on 19.07.2026.
//

import SwiftUI
import AppKit

struct LockScreenTrack: Equatable, Identifiable {
    let id: UUID
    let title: String
    let artist: String
    let artwork: NSImage?
}

enum PlaybackState: Equatable {
    case playing
    case paused
    case loading
}

enum LockScreenArtworkTransitionDirection: Equatable {
    case backward
    case forward
}

struct LockScreenMusicView: View {
    private let playerScale: CGFloat = 1.10

    let track: LockScreenTrack
    let playbackState: PlaybackState
    let progress: Double
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isLivestream: Bool
    let isShuffleEnabled: Bool
    let isShuffleAvailable: Bool
    let outputVolume: Double
    let isOutputMuted: Bool
    let audioActivityLevels: [CGFloat]
    let skipIndicator: String?
    let isArtworkExpanded: Bool
    let expandedArtworkSize: CGFloat
    let artworkTransitionDirection: LockScreenArtworkTransitionDirection

    let onArtworkTap: (() -> Void)?
    let onCollapseArtwork: (() -> Void)?
    let onTogglePlayback: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToggleShuffle: () -> Void
    let onToggleOutputMute: () -> Void
    let onPreviewSeek: (Double) -> Void
    let onSeek: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    @Namespace private var artworkNamespace

    init(
        track: LockScreenTrack,
        playbackState: PlaybackState,
        progress: Double,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isLivestream: Bool = false,
        isShuffleEnabled: Bool,
        isShuffleAvailable: Bool = true,
        outputVolume: Double = 0.5,
        isOutputMuted: Bool = false,
        audioActivityLevels: [CGFloat],
        skipIndicator: String? = nil,
        isArtworkExpanded: Bool = false,
        expandedArtworkSize: CGFloat = 339,
        artworkTransitionDirection: LockScreenArtworkTransitionDirection = .forward,
        onArtworkTap: (() -> Void)? = nil,
        onCollapseArtwork: (() -> Void)? = nil,
        onTogglePlayback: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onToggleShuffle: @escaping () -> Void,
        onToggleOutputMute: @escaping () -> Void,
        onPreviewSeek: @escaping (Double) -> Void,
        onSeek: @escaping (Double) -> Void
    ) {
        self.track = track
        self.playbackState = playbackState
        self.progress = progress
        self.currentTime = currentTime
        self.duration = duration
        self.isLivestream = isLivestream
        self.isShuffleEnabled = isShuffleEnabled
        self.isShuffleAvailable = isShuffleAvailable
        self.outputVolume = outputVolume
        self.isOutputMuted = isOutputMuted
        self.audioActivityLevels = audioActivityLevels
        self.skipIndicator = skipIndicator
        self.isArtworkExpanded = isArtworkExpanded
        self.expandedArtworkSize = expandedArtworkSize
        self.artworkTransitionDirection = artworkTransitionDirection
        self.onArtworkTap = onArtworkTap
        self.onCollapseArtwork = onCollapseArtwork
        self.onTogglePlayback = onTogglePlayback
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onToggleShuffle = onToggleShuffle
        self.onToggleOutputMute = onToggleOutputMute
        self.onPreviewSeek = onPreviewSeek
        self.onSeek = onSeek
    }

    private var clampedProgress: Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    private var title: String {
        track.title.isEmpty ? "Now Playing" : track.title
    }

    private var artist: String {
        track.artist.isEmpty ? "Music" : track.artist
    }

    var body: some View {
        playerSurface
            .scaleEffect(playerScale)
            .overlay(alignment: .top) {
                expandedArtworkView
                    .offset(y: -expandedArtworkSize - 18)
            }
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.96)
            .offset(y: hasAppeared ? 0 : 10)
            .onAppear {
                guard !hasAppeared else { return }

                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88, blendDuration: 0.04)) {
                        hasAppeared = true
                    }
                }
            }
    }

    @ViewBuilder
    private var playerSurface: some View {
        if #available(macOS 26.0, *) {
            playerContent
                .glassEffect(
                    .clear.interactive(),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
        } else {
            playerContent
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var playerContent: some View {
        VStack(spacing: 0) {
            trackInfoSection

            Group {
                if isLivestream {
                    LockScreenLivestreamView()
                } else {
                    PlaybackProgressView(
                        progress: clampedProgress,
                        currentTime: currentTime,
                        duration: duration,
                        onPreviewSeek: onPreviewSeek,
                        onSeek: onSeek
                    )
                }
            }
            .padding(.top, 12)

            PlaybackControlsView(
                playbackState: playbackState,
                isLivestream: isLivestream,
                isShuffleEnabled: isShuffleEnabled,
                isShuffleAvailable: isShuffleAvailable,
                onTogglePlayback: onTogglePlayback,
                onPrevious: onPrevious,
                onNext: onNext,
                onToggleShuffle: onToggleShuffle,
                outputVolume: outputVolume,
                isOutputMuted: isOutputMuted,
                onToggleOutputMute: onToggleOutputMute
            )
            .padding(.top, 13)
        }
        .padding(EdgeInsets(top: 17, leading: 18, bottom: 15, trailing: 18))
        .frame(minWidth: 320, idealWidth: 339, maxWidth: 363)
        .aspectRatio(2.2, contentMode: .fit)
        .frame(width: 339, height: 154)
    }

    private var trackInfoSection: some View {
        HStack(spacing: 12) {
            if !isArtworkExpanded {
                artworkButton
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(artist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .id(track.id)
            .frame(
                maxWidth: 165,
                alignment: .leading
            )
            .contentTransition(.opacity)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: track.id)

            Spacer(minLength: 8)

            AudioActivityIndicator(
                levels: audioActivityLevels,
                isActive: playbackState == .playing,
                skipIndicator: skipIndicator
            )
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .accessibilityLabel("Audio activity")
        }
        .frame(height: 48)
        .animation(reduceMotion ? nil : .smooth(duration: 0.30, extraBounce: 0), value: isArtworkExpanded)
    }

    private var artworkView: some View {
        ZStack {
            if let artwork = track.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                    .matchedGeometryEffect(id: "lock-screen-artwork", in: artworkNamespace)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
            }
        }
        .frame(width: 48, height: 48)
        .accessibilityLabel("\(title) artwork")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: track.id)
    }

    @ViewBuilder
    private var artworkButton: some View {
        if let onArtworkTap {
            Button(action: onArtworkTap) {
                artworkView
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) artwork")
        } else {
            artworkView
        }
    }

    @ViewBuilder
    private var expandedArtworkView: some View {
        if isArtworkExpanded,
           let artwork = track.artwork,
           let onCollapseArtwork {
            Button(action: onCollapseArtwork) {
                ZStack {
                    Image(nsImage: artwork)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFill()
                        .frame(width: expandedArtworkSize, height: expandedArtworkSize)
                        .id(track.id)
                        .transition(expandedArtworkTrackTransition)
                }
                .frame(width: expandedArtworkSize, height: expandedArtworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .matchedGeometryEffect(id: "lock-screen-artwork", in: artworkNamespace)
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .animation(
                    reduceMotion ? nil : .smooth(duration: 0.28, extraBounce: 0),
                    value: track.id
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collapse \(title) artwork")
        }
    }

    private var expandedArtworkTrackTransition: AnyTransition {
        let distance = expandedArtworkSize * 0.45
        let insertionOffset = artworkTransitionDirection == .forward ? distance : -distance

        return .asymmetric(
            insertion: .offset(x: insertionOffset).combined(with: .opacity),
            removal: .offset(x: -insertionOffset).combined(with: .opacity)
        )
    }
}

private struct LockScreenLivestreamView: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)

            Text("Livestream")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))

            Spacer()
        }
        .padding(.horizontal, 2)
        .frame(height: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Livestream")
    }
}

struct PlaybackProgressView: View {
    let progress: Double
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onPreviewSeek: (Double) -> Void
    let onSeek: (Double) -> Void

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragProgress: Double?

    private var clampedProgress: Double {
        let value = dragProgress ?? progress
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    private var formattedCurrentTime: String {
        LockScreenMusicTimeFormatter.string(from: currentTime)
    }

    private var formattedDuration: String {
        LockScreenMusicTimeFormatter.string(from: duration)
    }

    private var formattedRemainingTime: String {
        LockScreenMusicTimeFormatter.remainingString(currentTime: currentTime, duration: duration)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(formattedCurrentTime)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let fillWidth = max(10, width * clampedProgress)
                let thumbVisible = isHovering || isDragging

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(height: 8)

                    Capsule()
                        .fill(Color.white.opacity(0.90))
                        .frame(width: min(fillWidth, width), height: 8)

                    Circle()
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                        .offset(x: min(max(fillWidth - 4, 0), max(width - 8, 0)))
                        .opacity(thumbVisible ? 1 : 0)
                        .scaleEffect(thumbVisible ? 1 : 0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .overlay {
                    LockScreenProgressInteractionView(
                        onHoverChange: { hovering in
                            withAnimation(.easeOut(duration: 0.08)) {
                                isHovering = hovering
                            }
                        },
                        onPreviewSeek: { nextProgress in
                            isDragging = true
                            dragProgress = nextProgress
                            onPreviewSeek(nextProgress)
                        },
                        onSeek: { nextProgress in
                            dragProgress = nil
                            isDragging = false
                            onSeek(nextProgress)
                        }
                    )
                }
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.08)) {
                        isHovering = hovering
                    }
                }
                .animation(.easeOut(duration: 0.08), value: thumbVisible)
                .animation(.easeOut(duration: 0.08), value: clampedProgress)
            }
            .frame(height: 8)
            .accessibilityLabel("Playback progress")
            .accessibilityValue("\(formattedCurrentTime) of \(formattedDuration)")

            Text(formattedRemainingTime)
                .frame(width: 30, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(Color.white.opacity(0.78))
        .frame(height: 20)
    }

}

struct PlaybackControlsView: View {
    let playbackState: PlaybackState
    let isLivestream: Bool
    let isShuffleEnabled: Bool
    let isShuffleAvailable: Bool
    let onTogglePlayback: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToggleShuffle: () -> Void
    let outputVolume: Double
    let isOutputMuted: Bool
    let onToggleOutputMute: () -> Void

    private var displayVolume: Double {
        isOutputMuted ? 0 : min(max(outputVolume, 0), 1)
    }

    private var volumeIconName: String {
        switch displayVolume {
        case ...0.01:
            return "speaker.slash.fill"
        case ..<0.34:
            return "speaker.wave.1.fill"
        case ..<0.67:
            return "speaker.wave.2.fill"
        default:
            return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        HStack {
            Button(action: onToggleShuffle) {
                Image(systemName: "shuffle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        isShuffleEnabled
                            ? Color.white.opacity(0.96)
                            : Color.white.opacity(0.62)
                    )
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(LockScreenControlButtonStyle())
            .disabled(isLivestream || !isShuffleAvailable)
            .opacity((isLivestream || !isShuffleAvailable) ? 0.4 : 1)
            .accessibilityLabel(isShuffleEnabled ? "Disable Shuffle" : "Enable Shuffle")

            Spacer()

            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(LockScreenControlButtonStyle())
            .disabled(isLivestream)
            .opacity(isLivestream ? 0.4 : 1)
            .accessibilityLabel("Previous Track")

            Spacer()

            Button(action: onTogglePlayback) {
                ZStack {
                    switch playbackState {
                    case .loading:
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    case .playing:
                        Image(systemName: "pause.fill")
                            .font(.system(size: 18, weight: .bold))
                            .contentTransition(.symbolEffect(.replace))
                    case .paused:
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .foregroundStyle(Color.white.opacity(0.98))
                .frame(width: 38, height: 38)
            }
            .buttonStyle(LockScreenControlButtonStyle(pressedScale: 0.9))
            .disabled(playbackState == .loading)
            .accessibilityLabel(playbackState == .playing ? "Pause" : "Play")

            Spacer()

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(LockScreenControlButtonStyle())
            .disabled(isLivestream)
            .opacity(isLivestream ? 0.4 : 1)
            .accessibilityLabel("Next Track")

            Spacer()

            Button(action: onToggleOutputMute) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .frame(width: 34, height: 34)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(LockScreenControlButtonStyle())
            .accessibilityLabel(isOutputMuted || outputVolume <= 0.01 ? "Unmute" : "Mute")
        }
        .frame(height: 38)
    }
}

private struct LockScreenProgressInteractionView: NSViewRepresentable {
    let onHoverChange: (Bool) -> Void
    let onPreviewSeek: (Double) -> Void
    let onSeek: (Double) -> Void

    func makeNSView(context: Context) -> LockScreenProgressInteractionNSView {
        let view = LockScreenProgressInteractionNSView()
        view.onHoverChange = onHoverChange
        view.onPreviewSeek = onPreviewSeek
        view.onSeek = onSeek
        return view
    }

    func updateNSView(_ nsView: LockScreenProgressInteractionNSView, context: Context) {
        nsView.onHoverChange = onHoverChange
        nsView.onPreviewSeek = onPreviewSeek
        nsView.onSeek = onSeek
    }
}

private final class LockScreenProgressInteractionNSView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    var onPreviewSeek: ((Double) -> Void)?
    var onSeek: ((Double) -> Void)?

    private var trackingAreaRef: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self
        )

        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }

    override func mouseDown(with event: NSEvent) {
        onHoverChange?(true)
        onPreviewSeek?(progress(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        onPreviewSeek?(progress(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        onSeek?(progress(for: event))
    }

    private func progress(for event: NSEvent) -> Double {
        guard bounds.width > 0 else { return 0 }

        let point = convert(event.locationInWindow, from: nil)
        return min(max(Double(point.x / bounds.width), 0), 1)
    }
}

struct LockScreenControlButtonStyle: ButtonStyle {
    let hoverScale: CGFloat
    let pressedScale: CGFloat

    init(hoverScale: CGFloat = 1.04, pressedScale: CGFloat = 0.94) {
        self.hoverScale = hoverScale
        self.pressedScale = pressedScale
    }

    func makeBody(configuration: Configuration) -> some View {
        LockScreenControlButtonBody(
            configuration: configuration,
            hoverScale: hoverScale,
            pressedScale: pressedScale
        )
    }
}

private struct LockScreenControlButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let hoverScale: CGFloat
    let pressedScale: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var scale: CGFloat {
        if configuration.isPressed { return pressedScale }
        if isHovered && isEnabled { return hoverScale }
        return 1
    }

    private var backgroundOpacity: Double {
        if !isEnabled { return 0 }
        if configuration.isPressed { return 0.15 }
        return isHovered ? 0.10 : 0
    }

    var body: some View {
        configuration.label
            .contentShape(Circle())
            .background {
                Circle()
                    .fill(Color.white.opacity(backgroundOpacity))
            }
            .scaleEffect(scale)
            .opacity(isEnabled ? 1 : 0.42)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.08)) {
                    isHovered = hovering
                }
            }
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.08), value: isEnabled)
    }
}

private struct AudioActivityIndicator: View {
    let levels: [CGFloat]
    let isActive: Bool
    let skipIndicator: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var normalizedLevels: [CGFloat] {
        let values = levels.isEmpty ? [8, 14, 10, 16] : Array(levels.prefix(4))
        return values.map { min(max($0, 4), 18) }
    }

    var body: some View {
        ZStack {
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(normalizedLevels.enumerated()), id: \.offset) { index, level in
                    Capsule()
                        .fill(Color.white.opacity(isActive ? 0.90 : 0.56))
                        .frame(
                            width: 2,
                            height: isActive && !reduceMotion
                                ? animatedHeight(for: level, index: index)
                                : level
                        )
                        .animation(
                            isActive && !reduceMotion
                                ? .easeInOut(duration: 0.20 + Double(index) * 0.025)
                                    .repeatForever(autoreverses: true)
                                : .easeOut(duration: 0.12),
                            value: pulse
                        )
                }
            }
            .frame(width: 18, height: 18)
            .opacity(skipIndicator == nil ? 1 : 0.18)
            .scaleEffect(skipIndicator == nil ? 1 : 0.9)

            if let skipIndicator {
                Image(systemName: skipIndicator)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: 32, height: 32)
        .animation(.easeInOut(duration: 0.18), value: skipIndicator)
        .onAppear {
            guard isActive, !reduceMotion else { return }
            pulse = true
        }
        .onChange(of: isActive) { _, active in
            guard !reduceMotion else {
                pulse = false
                return
            }

            pulse = active
        }
    }

    private func animatedHeight(for level: CGFloat, index: Int) -> CGFloat {
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let delta = pulse ? direction * 2.5 : -direction * 1.5
        return min(max(level + delta, 4), 18)
    }
}

enum LockScreenMusicTimeFormatter {
    static func string(from time: TimeInterval) -> String {
        let totalSeconds = sanitizedSeconds(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    static func remainingString(currentTime: TimeInterval, duration: TimeInterval) -> String {
        let currentSeconds = sanitizedSeconds(currentTime)
        let durationSeconds = sanitizedSeconds(duration)
        return "-\(string(from: TimeInterval(max(durationSeconds - currentSeconds, 0))))"
    }

    private static func sanitizedSeconds(_ time: TimeInterval) -> Int {
        guard time.isFinite, !time.isNaN else { return 0 }
        return max(0, Int(time.rounded()))
    }
}

#Preview("Playing") {
    LockScreenMusicPreviewContainer(
        track: .preview(),
        playbackState: .playing,
        progress: 0.163,
        currentTime: 15,
        duration: 92,
        isShuffleEnabled: false,
        wallpaper: .dark
    )
}

#Preview("Paused") {
    LockScreenMusicPreviewContainer(
        track: .preview(title: "Ageispolis", artist: "Aphex Twin"),
        playbackState: .paused,
        progress: 0.48,
        currentTime: 122,
        duration: 254,
        isShuffleEnabled: true,
        wallpaper: .dark
    )
}

#Preview("Long Metadata") {
    LockScreenMusicPreviewContainer(
        track: .preview(
            title: "A Very Long Track Title That Should Truncate Beautifully",
            artist: "An Equally Long Artist Name With Several Collaborators"
        ),
        playbackState: .playing,
        progress: 0.72,
        currentTime: 274,
        duration: 381,
        isShuffleEnabled: false,
        wallpaper: .bright
    )
}

#Preview("Missing Artwork") {
    LockScreenMusicPreviewContainer(
        track: LockScreenTrack(id: UUID(), title: "No Cover", artist: "System Audio", artwork: nil),
        playbackState: .paused,
        progress: 0.28,
        currentTime: 37,
        duration: 132,
        isShuffleEnabled: false,
        wallpaper: .dark
    )
}

#Preview("Bright Wallpaper") {
    LockScreenMusicPreviewContainer(
        track: .preview(title: "The Call", artist: "Daniel Lopatin"),
        playbackState: .playing,
        progress: 0.163,
        currentTime: 15,
        duration: 92,
        isShuffleEnabled: false,
        wallpaper: .bright
    )
}

#Preview("Dark Wallpaper") {
    LockScreenMusicPreviewContainer(
        track: .preview(title: "The Call", artist: "Daniel Lopatin"),
        playbackState: .playing,
        progress: 0.163,
        currentTime: 15,
        duration: 92,
        isShuffleEnabled: false,
        wallpaper: .dark
    )
}

private struct LockScreenMusicPreviewContainer: View {
    enum Wallpaper {
        case bright
        case dark
    }

    let track: LockScreenTrack
    let playbackState: PlaybackState
    let progress: Double
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isShuffleEnabled: Bool
    let wallpaper: Wallpaper

    var body: some View {
        ZStack {
            previewWallpaper

            VStack {
                Spacer()

                LockScreenMusicView(
                    track: track,
                    playbackState: playbackState,
                    progress: progress,
                    currentTime: currentTime,
                    duration: duration,
                    isShuffleEnabled: isShuffleEnabled,
                    outputVolume: 0.72,
                    isOutputMuted: false,
                    audioActivityLevels: [7, 15, 10, 18],
                    onTogglePlayback: {},
                    onPrevious: {},
                    onNext: {},
                    onToggleShuffle: {},
                    onToggleOutputMute: {},
                    onPreviewSeek: { _ in },
                    onSeek: { _ in }
                )
                .padding(.bottom, 255)
            }
        }
        .frame(width: 1536, height: 1024)
    }

    @ViewBuilder
    private var previewWallpaper: some View {
        switch wallpaper {
        case .bright:
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.78, blue: 0.58),
                    Color(red: 0.66, green: 0.82, blue: 0.96),
                    Color(red: 0.96, green: 0.94, blue: 0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.13),
                    Color(red: 0.18, green: 0.24, blue: 0.29),
                    Color(red: 0.45, green: 0.32, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private extension LockScreenTrack {
    static func preview(
        title: String = "The Call",
        artist: String = "Daniel Lopatin"
    ) -> LockScreenTrack {
        LockScreenTrack(
            id: UUID(),
            title: title,
            artist: artist,
            artwork: PreviewArtworkFactory.makeArtwork()
        )
    }
}

private enum PreviewArtworkFactory {
    static func makeArtwork() -> NSImage {
        let size = NSSize(width: 128, height: 128)
        let image = NSImage(size: size)

        image.lockFocus()
        NSGradient(
            colors: [
                NSColor(calibratedRed: 0.92, green: 0.45, blue: 0.34, alpha: 1),
                NSColor(calibratedRed: 0.22, green: 0.34, blue: 0.58, alpha: 1)
            ]
        )?.draw(in: NSRect(origin: .zero, size: size), angle: 35)

        NSColor.white.withAlphaComponent(0.28).setFill()
        NSBezierPath(ovalIn: NSRect(x: 24, y: 20, width: 78, height: 78)).fill()

        NSColor.black.withAlphaComponent(0.2).setFill()
        NSBezierPath(ovalIn: NSRect(x: 48, y: 44, width: 34, height: 34)).fill()
        image.unlockFocus()

        return image
    }
}
