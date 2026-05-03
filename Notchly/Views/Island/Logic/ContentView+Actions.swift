//
//  ContentView+Actions.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI
import AppKit

extension ContentView {
    func handleAppear() {
        status = .closed
        showChargingPop = false
        isHovered = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            hasFinishedInitialAppear = true
        }
    }

    func handleHover(_ hovering: Bool) {
        isPointerInsideIsland = hovering

        withAnimation(.interactiveSpring(duration: 0.28, extraBounce: 0.02)) {
            isHovered = hovering
        }

        if !hovering, status == .opened || status == .musicPreview {
            scheduleAutoClose(after: 0.15)
        }
    }

    func closeIfOpened() {
        autoExpandMusicTask?.cancel()
        guard status == .opened || status == .musicPreview else { return }

        withAnimation(animation) {
            status = .closed
        }
    }

    func scheduleAutoClose(after seconds: Double = 2.0) {
        autoExpandMusicTask?.cancel()

        autoExpandMusicTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard status == .opened || status == .musicPreview else { return }
                guard !isPointerInsideIsland else { return }

                withAnimation(animation) {
                    status = .closed
                }
            }
        }
    }

    func performHapticFeedback() {
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }

    func animatePlayPauseButton() {
        playPauseBounce = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            playPauseBounce = false
        }
    }

    func showSkipIndicator(_ systemName: String) {
        withAnimation(.easeInOut(duration: 0.16)) {
            skipIndicator = systemName
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.18)) {
                skipIndicator = nil
            }
        }
    }
}
