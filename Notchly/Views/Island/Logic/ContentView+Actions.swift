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
        hideFocusStatusPreview(animated: false)

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

    func handleFocusEvent(isActive: Bool) {
        guard settingsManager.showFocusAnimations else { return }
        guard canShowFocusStatusAnimation else {
            queuePendingFocusEvent(isActive: isActive)
            return
        }

        pendingFocusEventTimestamp = nil
        startFocusStatusAnimation(isActive: isActive)
    }

    var canShowFocusStatusAnimation: Bool {
        animationsEnabled
            && dynamicManager.currentModule == .music
            && settingsManager.showMusic
            && musicManager.hasNowPlayingContent
    }

    func queuePendingFocusEvent(isActive: Bool) {
        pendingFocusEventIsActive = isActive
        pendingFocusEventTimestamp = Date.timeIntervalSinceReferenceDate
    }

    func playPendingFocusEventIfReady() {
        guard let timestamp = pendingFocusEventTimestamp else { return }

        guard settingsManager.showFocusAnimations else {
            pendingFocusEventTimestamp = nil
            return
        }

        guard Date.timeIntervalSinceReferenceDate - timestamp < 2.5 else {
            pendingFocusEventTimestamp = nil
            return
        }

        guard canShowFocusStatusAnimation else { return }

        let isActive = pendingFocusEventIsActive
        pendingFocusEventTimestamp = nil
        startFocusStatusAnimation(isActive: isActive)
    }

    private func startFocusStatusAnimation(isActive: Bool) {

        let collapseDuration = 0.34

        focusStatusTask?.cancel()
        autoExpandMusicTask?.cancel()
        showMusicVolumeControl = false
        focusStatusIsActive = isActive
        focusAnimationID += 1

        if status == .focusPreview {
            scheduleFocusReturn(
                returnStatus: focusReturnStatus,
                collapseDuration: collapseDuration
            )
            return
        }

        if status != .focusPreview && status != .focusCollapse {
            focusReturnStatus = status
        }

        focusCollapseShowsMusic = status != .focusCollapse || focusCollapseShowsMusic

        withAnimation(.smooth(duration: collapseDuration, extraBounce: 0)) {
            status = .focusCollapse
        }

        let returnStatus = focusReturnStatus

        focusStatusTask = Task {
            try? await Task.sleep(for: .seconds(collapseDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard status == .focusCollapse else { return }

                focusCollapseShowsMusic = false

                withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                    status = .focusPreview
                }
            }

            await MainActor.run {
                scheduleFocusReturn(
                    returnStatus: returnStatus,
                    collapseDuration: collapseDuration
                )
            }
        }
    }

    func scheduleFocusReturn(
        returnStatus: IslandStatus,
        collapseDuration: Double
    ) {
        focusStatusTask?.cancel()

        focusStatusTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard status == .focusPreview else { return }

                focusCollapseShowsMusic = false

                withAnimation(.smooth(duration: collapseDuration, extraBounce: 0)) {
                    status = .focusCollapse
                }
            }

            try? await Task.sleep(for: .seconds(collapseDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard status == .focusCollapse else { return }

                focusCollapseShowsMusic = true
                focusStatusTask = nil

                withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                    status = returnStatus
                }

                if (returnStatus == .opened || returnStatus == .musicPreview) && !isPointerInsideIsland {
                    scheduleAutoClose(after: 2.0)
                }
            }
        }
    }

    func hideFocusStatusPreview(animated: Bool = true) {
        focusStatusTask?.cancel()
        focusStatusTask = nil
        pendingFocusEventTimestamp = nil

        guard status == .focusPreview || status == .focusCollapse else { return }

        let updates = {
            focusCollapseShowsMusic = true
            status = focusReturnStatus
        }

        if animated {
            withAnimation(animation, updates)
        } else {
            updates()
        }
    }
}
