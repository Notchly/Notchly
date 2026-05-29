//
//  ChatGPTAppBridgeManager.swift
//  Notchly
//
//  Created by user on 29.05.2026.
//

import AppKit
import ApplicationServices

@MainActor
final class ChatGPTAppBridgeManager {
    private enum ResponseState {
        case idle
        case generating
    }

    private struct Snapshot {
        let isGenerating: Bool
        let textSignature: Int
        let textLength: Int
        let responseSnippet: String?
    }

    private let agentEventManager: AgentEventManager
    private var pollingTask: Task<Void, Never>?
    private var state: ResponseState = .idle
    private var lastSignature: Int?
    private var lastTextLength: Int?
    private var lastGeneratingFalseDate: Date?
    private var pendingStableSignature: Int?
    private var pendingStableLength: Int?
    private var pendingStableStartDate: Date?
    private var lastPublishedSignature: Int?
    private var lastPublishDate: Date?
    private var hasBaselineSnapshot = false
    private var didLogStart = false
    private var didLogAppFound = false
    private var didLogMissingAccessibility = false
    private var didLogMissingSnapshot = false
    private var lastSnapshotDebugDate: Date?
    private let accessibilityPromptWasShownKey = "chatGPTBridgeAccessibilityPromptWasShown"
    private let pollingIntervalMs = 450
    private let postGeneratingSettleDelay: TimeInterval = 0.8
    private let fallbackStableDuration: TimeInterval = 1.0
    private let completionPublishCooldown: TimeInterval = 3

    init(agentEventManager: AgentEventManager) {
        self.agentEventManager = agentEventManager
    }

    func start() {
        guard pollingTask == nil else { return }
        debugLog("started")

        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.pollChatGPT()
                try? await Task.sleep(for: .milliseconds(pollingIntervalMs))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        state = .idle
        lastSignature = nil
        lastTextLength = nil
        lastGeneratingFalseDate = nil
        pendingStableSignature = nil
        pendingStableLength = nil
        pendingStableStartDate = nil
        lastPublishedSignature = nil
        lastPublishDate = nil
        hasBaselineSnapshot = false
        didLogStart = false
        didLogAppFound = false
        didLogMissingAccessibility = false
        didLogMissingSnapshot = false
        lastSnapshotDebugDate = nil
        debugLog("stopped")
    }

    private func pollChatGPT() {
        if agentEventManager.currentEvent?.source.lowercased() == "chatgpt" {
            return
        }

        guard let app = chatGPTRunningApplication() else {
            resetRuntimeState()
            didLogAppFound = false
            return
        }

        if !didLogAppFound {
            didLogAppFound = true
            debugLog(
                "found ChatGPT app pid=\(app.processIdentifier) bundle=\(app.bundleIdentifier ?? "unknown") name=\(app.localizedName ?? "unknown")"
            )
        }

        guard isAccessibilityTrusted() else {
            if !didLogMissingAccessibility {
                didLogMissingAccessibility = true
                debugLog("accessibility is not trusted")
            }
            requestAccessibilityPermissionIfNeeded()
            return
        }

        if didLogMissingAccessibility {
            didLogMissingAccessibility = false
            debugLog("accessibility is trusted")
        }

        guard let snapshot = snapshot(for: app.processIdentifier) else {
            if !didLogMissingSnapshot {
                didLogMissingSnapshot = true
                debugLog("snapshot is empty; ChatGPT did not expose readable accessibility text")
            }
            return
        }

        didLogMissingSnapshot = false
        logSnapshot(snapshot)
        handle(snapshot)
    }

    private func handle(_ snapshot: Snapshot) {
        switch state {
        case .idle:
            guard snapshot.isGenerating else {
                handleStableTextFallback(snapshot)
                return
            }

            state = .generating
            lastSignature = snapshot.textSignature
            lastTextLength = snapshot.textLength
            lastGeneratingFalseDate = nil
            clearPendingStableSnapshot()
            debugLog("generating marker detected; waiting for completion")

        case .generating:
            if snapshot.isGenerating {
                lastGeneratingFalseDate = nil
                lastSignature = snapshot.textSignature
                lastTextLength = snapshot.textLength
                return
            }

            let now = Date()
            if lastGeneratingFalseDate == nil {
                lastGeneratingFalseDate = now
                return
            }

            guard let lastGeneratingFalseDate,
                  now.timeIntervalSince(lastGeneratingFalseDate) >= postGeneratingSettleDelay else {
                return
            }

            state = .idle
            self.lastGeneratingFalseDate = nil

            guard lastSignature != snapshot.textSignature else {
                lastSignature = snapshot.textSignature
                debugLog("generating marker ended, but signature did not change; skipping publish")
                return
            }

            guard canPublishCompletion(for: snapshot, at: now) else { return }

            lastSignature = snapshot.textSignature
            lastTextLength = snapshot.textLength
            lastPublishedSignature = snapshot.textSignature
            lastPublishDate = now
            clearPendingStableSnapshot()
            debugLog("publishing response generated from explicit generating marker")

            agentEventManager.publish(
                source: "chatgpt",
                kind: .completed,
                title: "Response generated",
                message: snapshot.responseSnippet ?? "Response ready",
                ttl: 3.0
            )
        }
    }

    private func handleStableTextFallback(_ snapshot: Snapshot) {
        defer {
            lastSignature = snapshot.textSignature
            lastTextLength = snapshot.textLength
        }

        guard hasBaselineSnapshot else {
            hasBaselineSnapshot = true
            debugLog("baseline snapshot captured length=\(snapshot.textLength)")
            return
        }

        guard let lastSignature else { return }
        guard snapshot.textSignature != lastSignature else {
            publishIfPendingSnapshotIsStable(snapshot)
            return
        }

        let lastTextLength = self.lastTextLength ?? snapshot.textLength
        let delta = snapshot.textLength - lastTextLength
        guard delta >= 40 else {
            if delta != 0 {
                debugLog("text changed but delta=\(delta) is below threshold")
            }
            clearPendingStableSnapshot()
            return
        }

        pendingStableSignature = snapshot.textSignature
        pendingStableLength = snapshot.textLength
        pendingStableStartDate = Date()
        debugLog("fallback candidate detected delta=\(delta) length=\(snapshot.textLength); waiting for stable state")
    }

    private func publishIfPendingSnapshotIsStable(_ snapshot: Snapshot) {
        guard let pendingStableSignature,
              pendingStableSignature == snapshot.textSignature,
              let pendingStableLength,
              pendingStableLength == snapshot.textLength,
              let pendingStableStartDate else {
            return
        }

        let now = Date()
        let stableDuration = now.timeIntervalSince(pendingStableStartDate)
        guard stableDuration >= fallbackStableDuration else { return }
        guard lastPublishedSignature != pendingStableSignature else {
            debugLog("fallback candidate already published; skipping")
            clearPendingStableSnapshot()
            return
        }

        guard canPublishCompletion(for: snapshot, at: now) else { return }

        lastPublishedSignature = pendingStableSignature
        lastPublishDate = now
        clearPendingStableSnapshot()
        debugLog("publishing response generated from stable text fallback after \(String(format: "%.1f", stableDuration))s")

        agentEventManager.publish(
            source: "chatgpt",
            kind: .completed,
            title: "Response generated",
            message: snapshot.responseSnippet ?? "Response ready",
            ttl: 3.0
        )
    }

    private func clearPendingStableSnapshot() {
        pendingStableSignature = nil
        pendingStableLength = nil
        pendingStableStartDate = nil
    }

    private func canPublishCompletion(for snapshot: Snapshot, at date: Date) -> Bool {
        if lastPublishedSignature == snapshot.textSignature {
            debugLog("completion already published for this snapshot; skipping")
            clearPendingStableSnapshot()
            return false
        }

        if let lastPublishDate,
           date.timeIntervalSince(lastPublishDate) < completionPublishCooldown {
            debugLog("completion suppressed by cooldown")
            clearPendingStableSnapshot()
            return false
        }

        return true
    }

    private func snapshot(for processIdentifier: pid_t) -> Snapshot? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        var visitedCount = 0
        var collectedText: [String] = []
        let isGenerating = scan(
            appElement,
            depth: 0,
            visitedCount: &visitedCount,
            collectedText: &collectedText
        )

        guard !collectedText.isEmpty else {
            debugLog("scan completed visited=\(visitedCount) textNodes=0")
            return nil
        }

        let joinedText = collectedText.joined(separator: "|")

        return Snapshot(
            isGenerating: isGenerating,
            textSignature: joinedText.hashValue,
            textLength: collectedText.reduce(0) { $0 + $1.count },
            responseSnippet: extractResponseSnippet(from: collectedText)
        )
    }

    private func scan(
        _ element: AXUIElement,
        depth: Int,
        visitedCount: inout Int,
        collectedText: inout [String]
    ) -> Bool {
        guard depth <= 8, visitedCount < 220 else { return false }
        visitedCount += 1

        var nodeText = ""

        let textAttributes: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXHelpAttribute as CFString
        ]

        for attribute in textAttributes {
            if let value: String = copyAttribute(attribute, from: element),
               !value.isEmpty {
                nodeText += " \(value)"
            }
        }

        if !nodeText.isEmpty {
            collectedText.append(normalizeText(nodeText))
        }

        let normalized = nodeText.lowercased()
        if normalized.contains("stop generating") ||
            normalized.contains("stop responding") ||
            normalized.contains("stop streaming") ||
            normalized.contains("stop response") ||
            normalized.contains("interrupt") ||
            normalized.contains("cancel generating") {
            return true
        }

        guard let children: [AXUIElement] = copyAttribute(kAXChildrenAttribute as CFString, from: element) else {
            return false
        }

        for child in children.prefix(80) {
            if scan(
                child,
                depth: depth + 1,
                visitedCount: &visitedCount,
                collectedText: &collectedText
            ) {
                return true
            }
        }

        return false
    }

    private func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? T
    }

    private func extractResponseSnippet(from collectedText: [String]) -> String? {
        var seen = Set<String>()
        let candidates = collectedText.compactMap { rawText -> String? in
            let text = normalizeText(rawText)
            guard text.count >= 24 else { return nil }
            guard !isChromeText(text) else { return nil }
            guard seen.insert(text).inserted else { return nil }
            return text
        }

        guard let candidate = candidates.last else { return nil }
        return trimmedSnippet(candidate)
    }

    private func normalizeText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isChromeText(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let blockedExactText = [
            "chatgpt",
            "new chat",
            "temporary chat",
            "new temporary chat",
            "search",
            "library",
            "settings",
            "message chatgpt",
            "ask anything",
            "regenerate",
            "copy",
            "thumbs up",
            "thumbs down"
        ]
        let blockedFragments = [
            "menu item",
            " button",
            "record meeting",
            "record button",
            "stop generating",
            "stop responding",
            "stop streaming",
            "cancel generating",
            "new temporary chat",
            "temporary chat menu"
        ]

        return blockedExactText.contains(normalized) ||
            blockedFragments.contains { normalized.contains($0) }
    }

    private func trimmedSnippet(_ text: String) -> String {
        let maxLength = 120
        guard text.count > maxLength else { return text }

        let endIndex = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func chatGPTRunningApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            let bundleIdentifier = app.bundleIdentifier?.lowercased() ?? ""
            let localizedName = app.localizedName?.lowercased() ?? ""

            return bundleIdentifier == "com.openai.chat" ||
                bundleIdentifier.contains("chatgpt") ||
                localizedName == "chatgpt"
        }
    }

    private func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: accessibilityPromptWasShownKey) else { return }
        UserDefaults.standard.set(true, forKey: accessibilityPromptWasShownKey)

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        debugLog("requested accessibility permission")

        agentEventManager.publish(
            source: "chatgpt",
            kind: .accessRequest,
            title: "Enable Accessibility",
            message: "Allow Notchly to read ChatGPT state",
            ttl: 2
        )
    }

    private func resetRuntimeState() {
        state = .idle
        lastSignature = nil
        lastTextLength = nil
        lastGeneratingFalseDate = nil
        clearPendingStableSnapshot()
        hasBaselineSnapshot = false
    }

    private func logSnapshot(_ snapshot: Snapshot) {
        let now = Date()
        guard lastSnapshotDebugDate == nil ||
                now.timeIntervalSince(lastSnapshotDebugDate ?? now) >= 4 else {
            return
        }

        lastSnapshotDebugDate = now
        debugLog(
            "snapshot length=\(snapshot.textLength) signature=\(snapshot.textSignature) isGenerating=\(snapshot.isGenerating) state=\(state) snippet=\(snapshot.responseSnippet ?? "nil")"
        )
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[ChatGPTBridge] \(message)")
        #endif
    }
}
