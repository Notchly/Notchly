//
//  LockScreenMusicPlayerView.swift
//  Notchly
//
//  Created by user on 14.05.2026.
//

import SwiftUI
import AppKit

struct LockScreenMusicPlayerView: View {
    @ObservedObject var musicManager: MusicManager
    let isVisible: Bool

    @State private var playPauseBounce = false
    @State private var previousButtonBounce = false
    @State private var nextButtonBounce = false
    @State private var artworkSlideDirection: CGFloat = 1
    @State private var playPauseBounceTask: Task<Void, Never>?
    @State private var skipBounceTask: Task<Void, Never>?

    private let artworkSize: CGFloat = 52
    private let artworkCornerRadius: CGFloat = 6.5

    private var isLivestream: Bool {
        musicManager.durationMs <= 0
    }

    private var progress: CGFloat {
        guard musicManager.durationMs > 0 else { return 0 }
        return CGFloat(min(max(musicManager.playbackPosition / musicManager.durationMs, 0), 1))
    }

    private var displayTitle: String {
        musicManager.trackTitle.isEmpty ? "Now Playing" : musicManager.trackTitle
    }

    private var displayArtist: String {
        musicManager.artistName.isEmpty ? musicManager.sourceName : musicManager.artistName
    }

    private var artworkTransitionKey: String {
        "\(musicManager.trackTitle)|\(musicManager.artistName)|\(musicManager.albumTitle)"
    }

    private var artworkInsertionEdge: Edge {
        artworkSlideDirection >= 0 ? .trailing : .leading
    }

    private var artworkRemovalEdge: Edge {
        artworkSlideDirection >= 0 ? .leading : .trailing
    }

    private var artworkTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: artworkInsertionEdge).combined(with: .opacity),
            removal: .move(edge: artworkRemovalEdge).combined(with: .opacity)
        )
        .combined(with: .scale(scale: 0.98))
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                artworkView

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(displayArtist.isEmpty ? "Music" : displayArtist)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .padding(.top, 7)

                Spacer(minLength: 12)

                Button(action: musicManager.openCurrentPlayerApp) {
                    EqualizerGlyph(
                        isActive: isVisible && musicManager.isPlaying,
                        color: .white.opacity(0.5)
                    )
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(IslandControlButtonStyle())
                .padding(.top, 5)
            }

            progressView

            HStack(spacing: 44) {
                Button {
                    previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 27, weight: .bold))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.white)
                        .scaleEffect(previousButtonBounce ? 1.08 : 1.0)
                        .animation(.interactiveSpring(duration: 0.2, extraBounce: 0.18), value: previousButtonBounce)
                }
                .buttonStyle(IslandControlButtonStyle())
                .disabled(isLivestream)
                .opacity(isLivestream ? 0.4 : 1.0)

                Button(action: togglePlay) {
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .frame(width: 42, height: 40)
                        .foregroundStyle(.white)
                        .scaleEffect(playPauseBounce ? 1.08 : 1.0)
                        .animation(.interactiveSpring(duration: 0.22, extraBounce: 0.22), value: playPauseBounce)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(IslandControlButtonStyle(pressedScale: 0.9))

                Button {
                    nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 27, weight: .bold))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.white)
                        .scaleEffect(nextButtonBounce ? 1.08 : 1.0)
                        .animation(.interactiveSpring(duration: 0.2, extraBounce: 0.18), value: nextButtonBounce)
                }
                .buttonStyle(IslandControlButtonStyle())
                .disabled(isLivestream)
                .opacity(isLivestream ? 0.4 : 1.0)
            }
        }
        .padding(.horizontal, 19)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 405, height: 168)
        .background {
            playerBackground
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 13)
        .onDisappear {
            playPauseBounceTask?.cancel()
            playPauseBounceTask = nil
            skipBounceTask?.cancel()
            skipBounceTask = nil
        }
    }

    private var playerBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 23, style: .continuous)

        return shape
            .fill(.ultraThinMaterial)
            .background {
                shape
                    .fill(Color.black.opacity(0.04))
            }
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.13),
                                musicManager.waveformColor.opacity(0.06),
                                Color(red: 0.16, green: 0.28, blue: 0.52).opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topLeading) {
                Ellipse()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 190, height: 62)
                    .blur(radius: 24)
                    .offset(x: -36, y: -31)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                Ellipse()
                    .fill(musicManager.waveformColor.opacity(0.05))
                    .frame(width: 190, height: 72)
                    .blur(radius: 32)
                    .offset(x: 46, y: 34)
                    .allowsHitTesting(false)
            }
            .clipShape(shape)
    }

    private var artworkView: some View {
        ZStack {
            if let artwork = musicManager.artworkImage {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: artworkSize, height: artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 7, y: 3)
                    .id(artworkTransitionKey)
                    .transition(artworkTransition)
            } else {
                RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: artworkSize, height: artworkSize)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .id("placeholder")
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(width: artworkSize, height: artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous))
        .animation(.easeInOut(duration: 0.28), value: artworkTransitionKey)
    }

    @ViewBuilder
    private var progressView: some View {
        if isLivestream {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)

                Text("Livestream")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()
            }
            .frame(height: 24)
        } else {
            HStack(spacing: 9) {
                Text(formatPlaybackTime(musicManager.playbackPosition / 1000))
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.74))
                    .frame(width: 32, alignment: .leading)

                LockScreenSeekBar(
                    progress: progress,
                    tintColor: musicManager.waveformColor,
                    onPreviewSeek: { musicManager.previewSeek(toProgress: $0) },
                    onSeek: { musicManager.seek(toProgress: $0) }
                )
                .frame(height: 20)

                Text(formatRemainingTime())
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.74))
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    private func togglePlay() {
        playPauseBounceTask?.cancel()
        playPauseBounce = true
        musicManager.togglePlay()

        playPauseBounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }
            playPauseBounce = false
            playPauseBounceTask = nil
        }
    }

    private func previousTrack() {
        animateSkip(direction: -1)
        musicManager.previousTrack()
    }

    private func nextTrack() {
        animateSkip(direction: 1)
        musicManager.nextTrack()
    }

    private func animateSkip(direction: CGFloat) {
        skipBounceTask?.cancel()
        artworkSlideDirection = direction

        withAnimation(.interactiveSpring(duration: 0.2, extraBounce: 0.18)) {
            if direction < 0 {
                previousButtonBounce = true
            } else {
                nextButtonBounce = true
            }
        }

        skipBounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }

            withAnimation(.interactiveSpring(duration: 0.2, extraBounce: 0.08)) {
                if direction < 0 {
                    previousButtonBounce = false
                } else {
                    nextButtonBounce = false
                }
            }

            skipBounceTask = nil
        }
    }

    private func formatPlaybackTime(_ totalSeconds: TimeInterval) -> String {
        let seconds = max(0, Int(totalSeconds.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatRemainingTime() -> String {
        let remainingSeconds = max(0, (musicManager.durationMs - musicManager.playbackPosition) / 1000)
        return "-\(formatPlaybackTime(remainingSeconds))"
    }
}

private struct LockScreenSeekBar: View {
    let progress: CGFloat
    let tintColor: Color
    let onPreviewSeek: (CGFloat) -> Void
    let onSeek: (CGFloat) -> Void

    @State private var isHovering = false
    @State private var isSeeking = false
    @State private var previewProgress: CGFloat?

    private var displayProgress: CGFloat {
        previewProgress ?? progress
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let fillWidth = max(7, width * displayProgress)
            let thumbVisible = isHovering || isSeeking

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                tintColor.opacity(0.92)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth, height: isSeeking ? 7 : 6)

                Circle()
                    .fill(Color.white)
                    .frame(width: isSeeking ? 13 : 10, height: isSeeking ? 13 : 10)
                    .shadow(color: tintColor.opacity(0.35), radius: 5)
                    .offset(x: min(max(fillWidth - 6, 0), width - 10))
                    .opacity(thumbVisible ? 1 : 0)
                    .scaleEffect(thumbVisible ? 1 : 0.72)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(.interactiveSpring(duration: 0.18, extraBounce: 0.06), value: isHovering)
            .animation(.interactiveSpring(duration: 0.18, extraBounce: 0.08), value: isSeeking)
            .animation(.easeInOut(duration: 0.12), value: displayProgress)
            .overlay {
                LockScreenSeekInteractionView(
                    onHoverChange: { hovering in
                        isHovering = hovering
                    },
                    onPreviewSeek: { nextProgress in
                        isSeeking = true
                        previewProgress = nextProgress
                        onPreviewSeek(nextProgress)
                    },
                    onSeek: { nextProgress in
                        onSeek(nextProgress)

                        withAnimation(.easeOut(duration: 0.12)) {
                            previewProgress = nil
                            isSeeking = false
                        }
                    }
                )
            }
        }
    }

    private func normalizedProgress(_ xPosition: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return progress }
        return min(max(xPosition / width, 0), 1)
    }
}

private struct LockScreenSeekInteractionView: NSViewRepresentable {
    let onHoverChange: (Bool) -> Void
    let onPreviewSeek: (CGFloat) -> Void
    let onSeek: (CGFloat) -> Void

    func makeNSView(context: Context) -> LockScreenSeekInteractionNSView {
        let view = LockScreenSeekInteractionNSView()
        view.onHoverChange = onHoverChange
        view.onPreviewSeek = onPreviewSeek
        view.onSeek = onSeek
        return view
    }

    func updateNSView(_ nsView: LockScreenSeekInteractionNSView, context: Context) {
        nsView.onHoverChange = onHoverChange
        nsView.onPreviewSeek = onPreviewSeek
        nsView.onSeek = onSeek
    }
}

private final class LockScreenSeekInteractionNSView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    var onPreviewSeek: ((CGFloat) -> Void)?
    var onSeek: ((CGFloat) -> Void)?

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

    private func progress(for event: NSEvent) -> CGFloat {
        guard bounds.width > 0 else { return 0 }

        let point = convert(event.locationInWindow, from: nil)
        return min(max(point.x / bounds.width, 0), 1)
    }
}
