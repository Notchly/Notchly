//
//  AgentEventManager.swift
//  Notchly
//
//  Created by user on 29.05.2026.
//

import Foundation
import Combine
import AppKit

enum AgentEventKind: String, Decodable {
    case accessRequest = "access_request"
    case clear
    case waiting
    case completed
    case failed
    case started
    case progress
    case cancelled
}

struct AgentEvent: Identifiable, Equatable {
    let id: UUID
    let source: String
    let kind: AgentEventKind
    let title: String
    let message: String?
    let ttl: TimeInterval
    let createdAt: Date

    var sourceLabel: String {
        switch source.lowercased() {
        case "codex":
            return "Codex"
        default:
            return source
        }
    }
}

private struct AgentEventPayload: Decodable {
    let source: String?
    let type: AgentEventKind?
    let title: String?
    let message: String?
    let ttl: TimeInterval?
}

@MainActor
final class AgentEventManager: ObservableObject {
    @Published private(set) var currentEvent: AgentEvent?
    @Published private(set) var eventID = 0

    private let settingsManager: SettingsManager
    private let fileManager = FileManager.default
    private var watchTask: Task<Void, Never>?
    private var clearTask: Task<Void, Never>?
    private var readOffset: UInt64 = 0
    private var lastShownEventKey: String?
    private var lastShownEventDate: Date?
    private var lastCompactionDate: Date?
    private let maxEventsFileSizeBytes: UInt64 = 512 * 1024
    private let maxEventsFileLines = 1200
    private let minCompactionInterval: TimeInterval = 30

    var eventsFileURL: URL {
        Self.eventsFileURL
    }

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    func publish(
        source: String,
        kind: AgentEventKind,
        title: String? = nil,
        message: String? = nil,
        ttl: TimeInterval? = nil
    ) {
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAllowedSource(normalizedSource) else {
            debugLog("ignored unsupported source=\(normalizedSource)")
            return
        }
        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedTitle: String
        if let normalizedTitle, !normalizedTitle.isEmpty {
            resolvedTitle = normalizedTitle
        } else {
            resolvedTitle = defaultTitle(for: kind, source: normalizedSource)
        }

        let event = AgentEvent(
            id: UUID(),
            source: normalizedSource,
            kind: kind,
            title: resolvedTitle,
            message: message?.trimmingCharacters(in: .whitespacesAndNewlines),
            ttl: resolvedTTL(for: kind, source: normalizedSource, payloadTTL: ttl),
            createdAt: Date()
        )

        showEvent(event)
    }

    func start() {
        guard watchTask == nil else { return }

        do {
            try ensureEventsFile()
            compactEventsFileIfNeeded(force: true)
            readOffset = currentFileSize()
        } catch {
            return
        }

        watchTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.readPendingEvents()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
        clearTask?.cancel()
        clearTask = nil
    }

    private func readPendingEvents() {
        guard fileManager.fileExists(atPath: eventsFileURL.path) else {
            try? ensureEventsFile()
            readOffset = 0
            return
        }

        let nextFileSize = currentFileSize()
        guard nextFileSize >= readOffset else {
            readOffset = nextFileSize
            return
        }
        guard nextFileSize > readOffset else { return }

        guard let handle = try? FileHandle(forReadingFrom: eventsFileURL) else { return }
        defer {
            try? handle.close()
        }

        do {
            try handle.seek(toOffset: readOffset)
            let data = handle.readDataToEndOfFile()
            readOffset += UInt64(data.count)
            decodeEvents(from: data)
            compactEventsFileIfNeeded()
        } catch {
            readOffset = nextFileSize
        }
    }

    private func decodeEvents(from data: Data) {
        guard let rawText = String(data: data, encoding: .utf8) else { return }

        rawText
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> AgentEvent? in
                let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, let lineData = text.data(using: .utf8) else { return nil }
                guard let payload = try? JSONDecoder().decode(AgentEventPayload.self, from: lineData) else { return nil }
                return makeEvent(from: payload)
            }
            .forEach(showEvent)
    }

    private func makeEvent(from payload: AgentEventPayload) -> AgentEvent? {
        let kind = payload.type ?? .completed
        let title = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = payload.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = payload.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard isAllowedSource(source) else {
            debugLog("ignored unsupported source=\(source)")
            return nil
        }
        let ttl = resolvedTTL(for: kind, source: source, payloadTTL: payload.ttl)
        let normalizedTitle = title?.isEmpty == false ? title : defaultTitle(for: kind, source: source)

        return AgentEvent(
            id: UUID(),
            source: source,
            kind: kind,
            title: normalizedTitle ?? defaultTitle(for: kind, source: source),
            message: message?.isEmpty == false ? message : nil,
            ttl: ttl,
            createdAt: Date()
        )
    }

    private func showEvent(_ event: AgentEvent) {
        if event.kind == .clear {
            clearCurrentEvent(for: event.source)
            return
        }

        let eventKey = duplicateKey(for: event)
        let now = Date()

        if let currentEvent,
           duplicateKey(for: currentEvent) == eventKey {
            debugLog("duplicate active event ignored key=\(eventKey)")
            return
        }

        if let lastShownEventKey,
           lastShownEventKey == eventKey,
           let lastShownEventDate,
           now.timeIntervalSince(lastShownEventDate) < max(event.ttl + 1, 3) {
            debugLog("recent duplicate event ignored key=\(eventKey)")
            return
        }

        lastShownEventKey = eventKey
        lastShownEventDate = now
        currentEvent = event
        eventID += 1
        debugLog("show event source=\(event.source) kind=\(event.kind.rawValue) ttl=\(event.ttl)")
        playCodexAlertSoundIfNeeded(for: event)

        clearTask?.cancel()
        guard shouldAutoClear(event) else {
            clearTask = nil
            debugLog("sticky event source=\(event.source) kind=\(event.kind.rawValue)")
            return
        }

        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(event.ttl))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.currentEvent?.id == event.id else { return }
                self?.currentEvent = nil
                self?.eventID += 1
                self?.debugLog("cleared event source=\(event.source) kind=\(event.kind.rawValue)")
            }
        }
    }

    private func clearCurrentEvent(for source: String) {
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard currentEvent?.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedSource else {
            debugLog("clear ignored source=\(source)")
            return
        }

        clearTask?.cancel()
        clearTask = nil
        currentEvent = nil
        eventID += 1
        debugLog("cleared event source=\(source) by hook")
    }

    private func shouldAutoClear(_ event: AgentEvent) -> Bool {
        let source = event.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if source == "codex", event.kind == .accessRequest {
            return false
        }

        return true
    }

    private func playCodexAlertSoundIfNeeded(for event: AgentEvent) {
        guard event.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "codex" else { return }
        guard event.kind != .clear else { return }

        switch event.kind {
        case .accessRequest, .waiting:
            guard settingsManager.enableCodexApprovalAlertSound else { return }
        case .completed:
            guard settingsManager.enableCodexCompletedAlertSound else { return }
        case .failed, .cancelled, .started, .progress:
            guard settingsManager.enableCodexCompletedAlertSound else { return }
        case .clear:
            return
        }

        CodexAlertSoundPlayer.shared.play(for: event.kind)
    }

    private func duplicateKey(for event: AgentEvent) -> String {
        [
            event.source.lowercased(),
            event.kind.rawValue,
            event.title,
            event.message ?? ""
        ].joined(separator: "|")
    }

    private func resolvedTTL(
        for kind: AgentEventKind,
        source: String,
        payloadTTL: TimeInterval?
    ) -> TimeInterval {
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedSource == "codex", kind == .completed {
            return min(max(settingsManager.codexCompletedAlertDuration, 1.5), 8)
        }

        return min(max(payloadTTL ?? defaultTTL(for: kind), 1.5), 30)
    }

    private func defaultTTL(for kind: AgentEventKind) -> TimeInterval {
        switch kind {
        case .clear:
            return 1.5
        case .accessRequest, .waiting:
            return 2
        case .failed, .cancelled:
            return 2
        case .started, .progress:
            return 2
        case .completed:
            return 3.0
        }
    }

    private func defaultTitle(for kind: AgentEventKind, source: String = "") -> String {
        if kind == .clear {
            return ""
        }

        if kind == .completed {
            return "Task completed"
        }

        switch kind {
        case .clear:
            return ""
        case .accessRequest:
            if source.lowercased() == "codex" {
                return "Need approval"
            }
            return "Access requested"
        case .waiting:
            return "Waiting for input"
        case .completed:
            return "Task completed"
        case .failed:
            return "Task failed"
        case .started:
            return "Task started"
        case .progress:
            return "Working"
        case .cancelled:
            return "Task cancelled"
        }
    }

    private func isAllowedSource(_ source: String) -> Bool {
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedSource == "codex"
    }

    private func ensureEventsFile() throws {
        try fileManager.createDirectory(
            at: Self.eventsDirectoryURL,
            withIntermediateDirectories: true
        )

        guard !fileManager.fileExists(atPath: eventsFileURL.path) else { return }
        fileManager.createFile(atPath: eventsFileURL.path, contents: nil)
    }

    private func compactEventsFileIfNeeded(force: Bool = false) {
        let now = Date()
        if !force,
           let lastCompactionDate,
           now.timeIntervalSince(lastCompactionDate) < minCompactionInterval {
            return
        }

        let fileSize = currentFileSize()
        guard force || fileSize > maxEventsFileSizeBytes else { return }

        guard let data = try? Data(contentsOf: eventsFileURL),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard lines.count > maxEventsFileLines else {
            lastCompactionDate = now
            return
        }

        let keptLines = lines.suffix(maxEventsFileLines)
        let compacted = keptLines.joined(separator: "\n") + "\n"

        do {
            try compacted.write(to: eventsFileURL, atomically: true, encoding: .utf8)
            readOffset = currentFileSize()
            lastCompactionDate = now
            debugLog("compacted events file lines=\(lines.count) -> \(keptLines.count)")
        } catch {
            return
        }
    }

    private func currentFileSize() -> UInt64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: eventsFileURL.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }

        return size.uint64Value
    }

    private static var eventsDirectoryURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notchly", isDirectory: true)
    }

    private static var eventsFileURL: URL {
        eventsDirectoryURL.appendingPathComponent("agent-events.jsonl")
    }

    private func debugLog(_ message: @autoclosure () -> String) {
        #if AGENT_EVENT_DEBUG
        print("[AgentEvent] \(message())")
        #endif
    }
}

@MainActor
final class CodexAlertSoundPlayer {
    static let shared = CodexAlertSoundPlayer()

    private let approvalSound = NSSound(named: NSSound.Name("Ping"))
    private let completedSound = NSSound(named: NSSound.Name("Glass"))
    private let fallbackSound = NSSound(named: NSSound.Name("Submarine"))
    private var lastPlayDate: Date?

    private init() {}

    func play(for kind: AgentEventKind, bypassThrottle: Bool = false) {
        let now = Date()
        if !bypassThrottle, let lastPlayDate, now.timeIntervalSince(lastPlayDate) < 0.35 {
            return
        }

        guard let sound = sound(for: kind) else { return }

        lastPlayDate = now
        sound.stop()
        sound.volume = kind == .accessRequest ? 0.24 : 0.18
        sound.play()
    }

    private func sound(for kind: AgentEventKind) -> NSSound? {
        switch kind {
        case .accessRequest, .waiting:
            return approvalSound ?? fallbackSound
        case .completed:
            return completedSound ?? fallbackSound
        case .failed, .cancelled:
            return fallbackSound ?? approvalSound ?? completedSound
        case .clear, .started, .progress:
            return completedSound ?? fallbackSound
        }
    }
}
