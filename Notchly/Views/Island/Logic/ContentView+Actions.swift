//
//  ContentView+Actions.swift
//  Notchly
//
//  Created by n0xbyte on 25.03.2026.
//

import SwiftUI
import AppKit

extension ContentView {
    func handleAppear() {
        status = .closed
        showChargingPop = false
        isHovered = false
        hideFocusStatusPreview(animated: false)
        hideBrightnessStatusPreview(animated: false)
        hideVolumeStatusPreview(animated: false)
        musicStartWidthTask?.cancel()
        musicStartWidthTask = nil
        musicStartUsesIdleWidth = false
        stagedMusicAutoOpenKey = ""
        musicEndWidthTask?.cancel()
        musicEndWidthTask = nil
        musicEndKeepsFullWidth = false
        lastMusicTrackSwipeTime = 0
        agentDismissTask?.cancel()
        agentDismissTask = nil
        agentPresentationStartedAt = nil
        agentPresentationTask?.cancel()
        agentPresentationTask = nil
        showsStandaloneAgentContent = false
        isStandaloneAgentClosing = false
        showsAgentMusicContent = false
        agentMusicContentAppeared = false
        hidesMusicContentDuringAgentReturn = false
        isAgentMusicClosing = false
        idleNotchSizeSuppressed = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            hasFinishedInitialAppear = true
        }
    }

    func handleHover(_ hovering: Bool) {
        guard isPointerInsideIsland != hovering else { return }

        isPointerInsideIsland = hovering

        withAnimation(.interactiveSpring(duration: 0.28, extraBounce: 0.02)) {
            isHovered = hovering
        }

        if !hovering, status == .opened || status == .musicPreview {
            scheduleAutoClose(after: 0.15)
        }
    }

    func handleNowPlayingContentChange(_ hasNowPlayingContent: Bool) {
        musicStartWidthTask?.cancel()
        musicStartWidthTask = nil
        musicEndWidthTask?.cancel()
        musicEndWidthTask = nil

        guard hasNowPlayingContent else {
            musicStartUsesIdleWidth = false
            stagedMusicAutoOpenKey = ""
            beginMusicEndWidthTransitionIfNeeded()
            return
        }

        musicEndKeepsFullWidth = false

        guard status == .closed else { return }
        guard !showChargingPop else { return }
        guard activeAgentEvent == nil else { return }

        musicStartUsesIdleWidth = true

        if musicManager.isPlaying {
            Task { @MainActor in
                handleMusicAutoExpand(isPlaying: true)
            }
        }

        musicStartWidthTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                    musicStartUsesIdleWidth = false
                }
                musicStartWidthTask = nil
            }
        }
    }

    func beginMusicEndWidthTransitionIfNeeded() {
        guard status == .closed else {
            musicEndKeepsFullWidth = false
            return
        }
        guard !showChargingPop else {
            musicEndKeepsFullWidth = false
            return
        }
        guard activeAgentEvent == nil else {
            musicEndKeepsFullWidth = false
            return
        }

        musicEndKeepsFullWidth = true

        musicEndWidthTask = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                    musicEndKeepsFullWidth = false
                }
                musicEndWidthTask = nil
            }
        }
    }

    func closeIfOpened() {
        autoExpandMusicTask?.cancel()
        guard status == .opened || status == .musicPreview else { return }

        withAnimation(animation) {
            status = .closed
        }
    }

    func handleAgentEventChange(_ event: AgentEvent?) {
        if let event {
            agentDismissTask?.cancel()
            agentDismissTask = nil
            agentPresentationTask?.cancel()
            agentPresentationTask = nil
            agentMusicHideTask?.cancel()
            showsStandaloneAgentContent = false
            isStandaloneAgentClosing = false
            displayedAgentEvent = event
            agentPresentationStartedAt = Date()
            if canShowAgentOverMusic {
                beginAgentMusicTransitionIfNeeded()
            } else {
                beginStandaloneAgentPresentation()
            }
        } else {
            if displayedAgentEvent == nil && !isAgentMusicTransitionActive &&
                (status == .agentPreview || status == .agentCollapse) {
                withAnimation(animation) {
                    status = .closed
                }
            }
            dismissAgentPresentationAfterMinimumDelay()
        }
    }

    func dismissAgentPresentationAfterMinimumDelay() {
        let remainingDelay = remainingAgentPresentationDelay()

        guard remainingDelay > 0 else {
            performAgentPresentationDismissal()
            return
        }

        agentDismissTask?.cancel()
        agentDismissTask = Task {
            try? await Task.sleep(for: .seconds(remainingDelay))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard agentEventManager.currentEvent == nil else { return }
                performAgentPresentationDismissal()
            }
        }
    }

    func remainingAgentPresentationDelay() -> TimeInterval {
        guard let displayedAgentEvent, displayedAgentEvent.kind == .completed else { return 0 }
        guard let agentPresentationStartedAt else { return 0 }

        let minimumDuration = displayedAgentEvent.ttl
        return max(0, minimumDuration - Date().timeIntervalSince(agentPresentationStartedAt))
    }

    func performAgentPresentationDismissal() {
        agentDismissTask?.cancel()
        agentDismissTask = nil

        if isAgentMusicTransitionActive {
            hideAgentMusicContent()
        } else {
            hideStandaloneAgentPresentationIfNeeded()
        }
    }

    func beginStandaloneAgentPresentation() {
        autoExpandMusicTask?.cancel()
        focusStatusTask?.cancel()
        brightnessStatusTask?.cancel()
        volumeStatusTask?.cancel()
        musicStartWidthTask?.cancel()
        musicStartWidthTask = nil
        musicStartUsesIdleWidth = false
        musicEndWidthTask?.cancel()
        musicEndWidthTask = nil
        musicEndKeepsFullWidth = false
        showChargingPop = false
        showMusicVolumeControl = false
        isAgentMusicTransitionActive = false
        showsAgentMusicContent = false
        agentMusicContentAppeared = false
        hidesMusicContentDuringAgentReturn = false
        isAgentMusicClosing = false

        let baseExpandDuration = 0.3
        let expandDuration = 0.42
        let contentDelay = 0.08
        let contentDuration = 0.28

        withAnimation(.smooth(duration: baseExpandDuration, extraBounce: 0)) {
            showsStandaloneAgentContent = false
            isStandaloneAgentClosing = false
            idleNotchSizeSuppressed = true
            status = .closed
        }

        agentPresentationTask?.cancel()
        agentPresentationTask = Task {
            try? await Task.sleep(for: .seconds(baseExpandDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard activeAgentEvent != nil else { return }
                guard status == .closed else { return }

                withAnimation(.smooth(duration: expandDuration, extraBounce: 0)) {
                    status = .agentPreview
                }
            }

            try? await Task.sleep(for: .seconds(contentDelay))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard activeAgentEvent != nil else { return }
                guard status == .agentPreview else { return }

                withAnimation(.smooth(duration: contentDuration, extraBounce: 0)) {
                    showsStandaloneAgentContent = true
                }

                agentPresentationTask = nil
            }
        }
    }

    func hideStandaloneAgentPresentationIfNeeded() {
        guard !isAgentMusicTransitionActive else { return }
        guard status == .agentPreview || status == .agentCollapse || status == .closed else {
            withAnimation(.smooth(duration: 0.3, extraBounce: 0)) {
                idleNotchSizeSuppressed = false
                showsStandaloneAgentContent = false
                isStandaloneAgentClosing = false
                displayedAgentEvent = nil
                agentPresentationStartedAt = nil
            }
            return
        }

        let returnDuration = 0.5
        let idleReturnDuration = 0.42

        withAnimation(animation) {
            isStandaloneAgentClosing = true
            idleNotchSizeSuppressed = true
            status = .closed
        }

        agentDismissTask?.cancel()
        agentDismissTask = Task {
            try? await Task.sleep(for: .seconds(returnDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard agentEventManager.currentEvent == nil else { return }
                guard status == .closed else { return }

                showsStandaloneAgentContent = false

                withAnimation(animation) {
                    idleNotchSizeSuppressed = false
                }
            }

            try? await Task.sleep(for: .seconds(idleReturnDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard agentEventManager.currentEvent == nil else { return }
                isStandaloneAgentClosing = false
                displayedAgentEvent = nil
                agentPresentationStartedAt = nil
                agentDismissTask = nil
            }
        }
    }

    func beginAgentMusicTransitionIfNeeded() {
        guard canShowAgentOverMusic else { return }

        autoExpandMusicTask?.cancel()
        focusStatusTask?.cancel()
        brightnessStatusTask?.cancel()
        volumeStatusTask?.cancel()
        showMusicVolumeControl = false

        if !isAgentMusicTransitionActive {
            agentMusicReturnStatus = status
        }

        isAgentMusicTransitionActive = true
        isAgentMusicClosing = false
        agentCollapseShowsMusic = false
        showsAgentMusicContent = true
        agentMusicContentAppeared = false

        withAnimation(animation) {
            status = .agentPreview
        }

        Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard isAgentMusicTransitionActive else { return }
                guard !isAgentMusicClosing else { return }
                guard agentEventManager.currentEvent != nil || displayedAgentEvent != nil else { return }

                agentMusicContentAppeared = true
            }
        }
    }

    func hideAgentMusicContent() {
        guard isAgentMusicTransitionActive else {
            displayedAgentEvent = nil
            agentPresentationStartedAt = nil
            showsAgentMusicContent = false
            agentMusicContentAppeared = false
            hidesMusicContentDuringAgentReturn = false
            isAgentMusicClosing = false
            return
        }

        agentMusicHideTask?.cancel()

        finishAgentMusicTransitionIfNeeded()
    }

    func finishAgentMusicTransitionIfNeeded() {
        guard isAgentMusicTransitionActive else { return }

        let targetStatus = resolvedAgentMusicReturnStatus()
        let returnDuration = 0.5

        hidesMusicContentDuringAgentReturn = false
        showsAgentMusicContent = true
        agentMusicContentAppeared = true
        isAgentMusicClosing = true

        guard settingsManager.showMusic,
              musicManager.hasNowPlayingContent else {
            withAnimation(animation) {
                status = .closed
            }

            agentMusicHideTask?.cancel()
            agentMusicHideTask = Task {
                try? await Task.sleep(for: .seconds(returnDuration))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    // Drop the notification layer before music content is allowed to render again.
                    hidesMusicContentDuringAgentReturn = true
                    showsAgentMusicContent = false
                    agentMusicContentAppeared = false
                    isAgentMusicClosing = false
                    displayedAgentEvent = nil
                    agentPresentationStartedAt = nil
                }

                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    isAgentMusicTransitionActive = false
                    hidesMusicContentDuringAgentReturn = false
                    agentMusicHideTask = nil
                }
            }
            return
        }

        withAnimation(animation) {
            status = targetStatus
        }

        if (targetStatus == .opened || targetStatus == .musicPreview) && !isPointerInsideIsland {
            scheduleAutoClose(after: 2.0)
        }

        agentMusicHideTask?.cancel()
        agentMusicHideTask = Task {
            try? await Task.sleep(for: .seconds(returnDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard agentEventManager.currentEvent == nil else { return }

                // Drop the notification layer before music content is allowed to render again.
                hidesMusicContentDuringAgentReturn = true
                showsAgentMusicContent = false
                agentMusicContentAppeared = false
                isAgentMusicClosing = false
                displayedAgentEvent = nil
                agentPresentationStartedAt = nil
            }

            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard agentEventManager.currentEvent == nil else { return }

                isAgentMusicTransitionActive = false
                hidesMusicContentDuringAgentReturn = false
                agentMusicHideTask = nil
            }
        }
    }

    func resolvedAgentMusicReturnStatus() -> IslandStatus {
        guard displayedAgentEvent?.kind != .completed else { return .closed }

        switch agentMusicReturnStatus {
        case .opened:
            return .opened
        default:
            return .closed
        }
    }

    func openAgentSourceApp(_ event: AgentEvent?) {
        guard let source = event?.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return }

        let workspace = NSWorkspace.shared

        for bundleIdentifier in agentBundleIdentifiers(for: source) {
            if let runningApp = workspace.runningApplications.first(where: {
                $0.bundleIdentifier?.lowercased() == bundleIdentifier
            }) {
                runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }

            if let applicationURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                workspace.openApplication(at: applicationURL, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }

        if let runningApp = workspace.runningApplications.first(where: { app in
            let bundleIdentifier = app.bundleIdentifier?.lowercased() ?? ""
            let localizedName = app.localizedName?.lowercased() ?? ""

            return agentSourceMatchesRunningApplication(
                source: source,
                bundleIdentifier: bundleIdentifier,
                localizedName: localizedName
            )
        }) {
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }

        return
    }

    private func agentBundleIdentifiers(for source: String) -> [String] {
        switch source {
        case "codex":
            return ["com.openai.codex"]
        case "cursor":
            return [
                "com.todesktop.230313mzl4w4u92",
                "com.cursor.Cursor"
            ]
        default:
            return []
        }
    }

    private func agentSourceMatchesRunningApplication(
        source: String,
        bundleIdentifier: String,
        localizedName: String
    ) -> Bool {
        switch source {
        case "codex":
            return bundleIdentifier.contains("codex") ||
            localizedName == "codex" ||
            localizedName.contains("codex")
        case "cursor":
            return bundleIdentifier.contains("cursor") ||
            localizedName == "cursor" ||
            localizedName.contains("cursor")
        default:
            return false
        }
    }

    func agentPresentationContentKey(for event: AgentEvent?) -> String {
        guard let event else { return "agent-empty" }

        return [
            event.source.lowercased(),
            event.kind.rawValue,
            event.title,
            event.message ?? ""
        ].joined(separator: "|")
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
        guard !isAgentAlertBlockingOtherEvents else {
            pendingFocusEventTimestamp = nil
            return
        }
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
    }

    func queuePendingFocusEvent(isActive: Bool) {
        pendingFocusEventIsActive = isActive
        pendingFocusEventTimestamp = Date.timeIntervalSinceReferenceDate
    }

    func playPendingFocusEventIfReady() {
        guard !isAgentAlertBlockingOtherEvents else {
            pendingFocusEventTimestamp = nil
            return
        }
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
        guard !isAgentAlertBlockingOtherEvents else { return }

        let collapseDuration = 0.34

        focusStatusTask?.cancel()
        brightnessStatusTask?.cancel()
        volumeStatusTask?.cancel()
        autoExpandMusicTask?.cancel()
        showMusicVolumeControl = false
        focusStatusIsActive = isActive
        hidesFocusStatusContentDuringReturn = false
        pendingBrightnessEventTimestamp = nil
        pendingVolumeEventTimestamp = nil

        if status == .focusPreview {
            scheduleFocusReturn(
                returnStatus: focusReturnStatus,
                collapseDuration: collapseDuration
            )
            return
        }

        if status == .brightnessPreview || status == .brightnessCollapse {
            brightnessCollapseShowsMusic = true
            hidesBrightnessStatusContentDuringReturn = false
            status = brightnessReturnStatus
        }

        if status == .volumePreview || status == .volumeCollapse {
            volumeCollapseShowsMusic = true
            hidesVolumeStatusContentDuringReturn = false
            status = volumeReturnStatus
        }

        if status != .focusPreview && status != .focusCollapse {
            focusReturnStatus = status
        }

        let canCollapseFromMusic =
            dynamicManager.currentModule == .music &&
            settingsManager.showMusic &&
            musicManager.hasNowPlayingContent

        focusCollapseShowsMusic =
            canCollapseFromMusic &&
            (status != .focusCollapse || focusCollapseShowsMusic)

        withAnimation(.smooth(duration: collapseDuration, extraBounce: 0)) {
            status = .focusCollapse
        }

        let returnStatus = focusReturnStatus

        focusStatusTask = Task {
            try? await Task.sleep(for: .seconds(collapseDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .focusCollapse else { return }

                focusCollapseShowsMusic = false

                withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                    status = .focusPreview
                }
            }

            await MainActor.run {
                focusStatusTask = nil
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
            try? await Task.sleep(for: .seconds(settingsManager.focusAnimationDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .focusPreview else { return }

                focusCollapseShowsMusic = false
                hidesFocusStatusContentDuringReturn = true

                withAnimation(.smooth(duration: collapseDuration, extraBounce: 0)) {
                    status = .focusCollapse
                }
            }

            try? await Task.sleep(for: .seconds(collapseDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .focusCollapse else { return }

                focusCollapseShowsMusic = true
                hidesFocusStatusContentDuringReturn = false
                focusStatusTask = nil

                withAnimation(.smooth(duration: 0.64, extraBounce: 0)) {
                    status = returnStatus
                }

                if (returnStatus == .opened || returnStatus == .musicPreview) && !isPointerInsideIsland {
                    scheduleAutoClose(after: 2.0)
                }
            }
        }
    }

    func handleBrightnessEvent() {
        guard !isAgentAlertBlockingOtherEvents else {
            pendingBrightnessEventTimestamp = nil
            return
        }
        guard settingsManager.showBrightnessStatus else { return }

        lastBrightnessStatusEventTime = Date.timeIntervalSinceReferenceDate

        guard canShowBrightnessStatusAnimation else {
            queuePendingBrightnessEvent()
            return
        }

        pendingBrightnessEventTimestamp = nil
        startBrightnessStatusAnimation()
    }

    var canShowBrightnessStatusAnimation: Bool {
        animationsEnabled && settingsManager.showBrightnessStatus
    }

    func queuePendingBrightnessEvent() {
        pendingBrightnessEventTimestamp = Date.timeIntervalSinceReferenceDate
    }

    func playPendingBrightnessEventIfReady() {
        guard !isAgentAlertBlockingOtherEvents else {
            pendingBrightnessEventTimestamp = nil
            return
        }
        guard let timestamp = pendingBrightnessEventTimestamp else { return }

        guard Date.timeIntervalSinceReferenceDate - timestamp < 2.5 else {
            pendingBrightnessEventTimestamp = nil
            return
        }

        guard canShowBrightnessStatusAnimation else { return }

        pendingBrightnessEventTimestamp = nil
        startBrightnessStatusAnimation()
    }

    private func startBrightnessStatusAnimation() {
        guard !isAgentAlertBlockingOtherEvents else { return }

        let collapseDuration = 0.34

        if status == .brightnessCollapse {
            return
        }

        if status == .brightnessPreview {
            scheduleBrightnessReturn(
                returnStatus: brightnessReturnStatus,
                collapseDuration: collapseDuration
            )
            return
        }

        brightnessStatusTask?.cancel()
        focusStatusTask?.cancel()
        volumeStatusTask?.cancel()
        autoExpandMusicTask?.cancel()
        showMusicVolumeControl = false
        hidesBrightnessStatusContentDuringReturn = false
        pendingFocusEventTimestamp = nil
        pendingVolumeEventTimestamp = nil

        if status == .focusPreview || status == .focusCollapse {
            focusCollapseShowsMusic = true
            hidesFocusStatusContentDuringReturn = false
            status = focusReturnStatus
        }

        if status == .volumePreview || status == .volumeCollapse {
            volumeCollapseShowsMusic = true
            hidesVolumeStatusContentDuringReturn = false
            status = volumeReturnStatus
        }

        if status != .brightnessPreview && status != .brightnessCollapse {
            brightnessReturnStatus = status
        }

        let canCollapseFromMusic =
            dynamicManager.currentModule == .music &&
            settingsManager.showMusic &&
            musicManager.hasNowPlayingContent

        brightnessCollapseShowsMusic =
            canCollapseFromMusic &&
            (status != .brightnessCollapse || brightnessCollapseShowsMusic)

        withAnimation(.smooth(duration: collapseDuration, extraBounce: 0)) {
            status = .brightnessCollapse
        }

        let returnStatus = brightnessReturnStatus

        brightnessStatusTask = Task {
            try? await Task.sleep(for: .seconds(collapseDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .brightnessCollapse else { return }

                brightnessCollapseShowsMusic = false

                withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                    status = .brightnessPreview
                }
            }

            await MainActor.run {
                brightnessStatusTask = nil
                scheduleBrightnessReturn(
                    returnStatus: returnStatus,
                    collapseDuration: collapseDuration
                )
            }
        }
    }

    func scheduleBrightnessReturn(
        returnStatus: IslandStatus,
        collapseDuration: Double
    ) {
        guard brightnessStatusTask == nil else { return }

        brightnessStatusTask = Task {
            while !Task.isCancelled {
                let elapsed = Date.timeIntervalSinceReferenceDate - lastBrightnessStatusEventTime
                let remainingDelay = max(0, 1.3 - elapsed)

                if remainingDelay <= 0 {
                    break
                }

                try? await Task.sleep(for: .seconds(remainingDelay))
            }

            guard !Task.isCancelled else {
                brightnessStatusTask = nil
                return
            }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .brightnessPreview else { return }

                brightnessCollapseShowsMusic = false
                hidesBrightnessStatusContentDuringReturn = true

                withAnimation(.smooth(duration: collapseDuration, extraBounce: 0)) {
                    status = .brightnessCollapse
                }
            }

            try? await Task.sleep(for: .seconds(collapseDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .brightnessCollapse else { return }

                brightnessCollapseShowsMusic = true
                hidesBrightnessStatusContentDuringReturn = false
                brightnessStatusTask = nil

                withAnimation(.smooth(duration: 0.64, extraBounce: 0)) {
                    status = returnStatus
                }

                if (returnStatus == .opened || returnStatus == .musicPreview) && !isPointerInsideIsland {
                    scheduleAutoClose(after: 2.0)
                }
            }
        }
    }

    func handleVolumeEvent() {
        guard !isAgentAlertBlockingOtherEvents else {
            pendingVolumeEventTimestamp = nil
            return
        }
        guard settingsManager.showSoundStatus else { return }

        lastVolumeStatusEventTime = Date.timeIntervalSinceReferenceDate

        guard canShowVolumeStatusAnimation else {
            queuePendingVolumeEvent()
            return
        }

        pendingVolumeEventTimestamp = nil
        startVolumeStatusAnimation()
    }

    var canShowVolumeStatusAnimation: Bool {
        animationsEnabled && settingsManager.showSoundStatus
    }

    func queuePendingVolumeEvent() {
        pendingVolumeEventTimestamp = Date.timeIntervalSinceReferenceDate
    }

    func playPendingVolumeEventIfReady() {
        guard !isAgentAlertBlockingOtherEvents else {
            pendingVolumeEventTimestamp = nil
            return
        }
        guard let timestamp = pendingVolumeEventTimestamp else { return }

        guard Date.timeIntervalSinceReferenceDate - timestamp < 2.5 else {
            pendingVolumeEventTimestamp = nil
            return
        }

        guard canShowVolumeStatusAnimation else { return }

        pendingVolumeEventTimestamp = nil
        startVolumeStatusAnimation()
    }

    private func startVolumeStatusAnimation() {
        guard !isAgentAlertBlockingOtherEvents else { return }

        let collapseDuration = 0.34

        if status == .volumeCollapse {
            return
        }

        if status == .volumePreview {
            scheduleVolumeReturn(
                returnStatus: volumeReturnStatus,
                collapseDuration: collapseDuration
            )
            return
        }

        volumeStatusTask?.cancel()
        focusStatusTask?.cancel()
        brightnessStatusTask?.cancel()
        autoExpandMusicTask?.cancel()
        showMusicVolumeControl = false
        hidesVolumeStatusContentDuringReturn = false
        pendingFocusEventTimestamp = nil
        pendingBrightnessEventTimestamp = nil

        if status == .focusPreview || status == .focusCollapse {
            focusCollapseShowsMusic = true
            hidesFocusStatusContentDuringReturn = false
            status = focusReturnStatus
        }

        if status == .brightnessPreview || status == .brightnessCollapse {
            brightnessCollapseShowsMusic = true
            hidesBrightnessStatusContentDuringReturn = false
            status = brightnessReturnStatus
        }

        if status != .volumePreview && status != .volumeCollapse {
            volumeReturnStatus = status
        }

        let canCollapseFromMusic =
            dynamicManager.currentModule == .music &&
            settingsManager.showMusic &&
            musicManager.hasNowPlayingContent

        volumeCollapseShowsMusic =
            canCollapseFromMusic &&
            (status != .volumeCollapse || volumeCollapseShowsMusic)

        withAnimation(.smooth(duration: collapseDuration, extraBounce: 0)) {
            status = .volumeCollapse
        }

        let returnStatus = volumeReturnStatus

        volumeStatusTask = Task {
            try? await Task.sleep(for: .seconds(collapseDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .volumeCollapse else { return }

                volumeCollapseShowsMusic = false

                withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                    status = .volumePreview
                }
            }

            await MainActor.run {
                volumeStatusTask = nil
                scheduleVolumeReturn(
                    returnStatus: returnStatus,
                    collapseDuration: collapseDuration
                )
            }
        }
    }

    func scheduleVolumeReturn(
        returnStatus: IslandStatus,
        collapseDuration: Double
    ) {
        guard volumeStatusTask == nil else { return }

        volumeStatusTask = Task {
            while !Task.isCancelled {
                let elapsed = Date.timeIntervalSinceReferenceDate - lastVolumeStatusEventTime
                let remainingDelay = max(0, 1.3 - elapsed)

                if remainingDelay <= 0 {
                    break
                }

                try? await Task.sleep(for: .seconds(remainingDelay))
            }

            guard !Task.isCancelled else {
                volumeStatusTask = nil
                return
            }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .volumePreview else { return }

                volumeCollapseShowsMusic = false
                hidesVolumeStatusContentDuringReturn = true

                withAnimation(.smooth(duration: collapseDuration, extraBounce: 0)) {
                    status = .volumeCollapse
                }
            }

            try? await Task.sleep(for: .seconds(collapseDuration))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !isAgentAlertBlockingOtherEvents else { return }
                guard status == .volumeCollapse else { return }

                volumeCollapseShowsMusic = true
                hidesVolumeStatusContentDuringReturn = false
                volumeStatusTask = nil

                withAnimation(.smooth(duration: 0.64, extraBounce: 0)) {
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
            hidesFocusStatusContentDuringReturn = false
            status = focusReturnStatus
        }

        if animated {
            withAnimation(animation, updates)
        } else {
            updates()
        }
    }

    func hideBrightnessStatusPreview(animated: Bool = true) {
        brightnessStatusTask?.cancel()
        brightnessStatusTask = nil
        pendingBrightnessEventTimestamp = nil

        guard status == .brightnessPreview || status == .brightnessCollapse else { return }

        let updates = {
            brightnessCollapseShowsMusic = true
            hidesBrightnessStatusContentDuringReturn = false
            status = brightnessReturnStatus
        }

        if animated {
            withAnimation(animation, updates)
        } else {
            updates()
        }
    }

    func hideVolumeStatusPreview(animated: Bool = true) {
        volumeStatusTask?.cancel()
        volumeStatusTask = nil
        pendingVolumeEventTimestamp = nil

        guard status == .volumePreview || status == .volumeCollapse else { return }

        let updates = {
            volumeCollapseShowsMusic = true
            hidesVolumeStatusContentDuringReturn = false
            status = volumeReturnStatus
        }

        if animated {
            withAnimation(animation, updates)
        } else {
            updates()
        }
    }
}
