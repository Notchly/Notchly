//
//  CodexHookIntegrationManager.swift
//  Notchly
//
//  Created by user on 29.05.2026.
//

import Foundation
import Combine

@MainActor
final class CodexHookIntegrationManager: ObservableObject {
    enum InstallState {
        case unknown
        case installing
        case installed
        case notInstalled
        case failed(String)
    }

    @Published private(set) var installState: InstallState = .unknown

    private let fileManager = FileManager.default

    var isInstalled: Bool {
        if case .installed = installState {
            return true
        }
        return false
    }

    var configPreview: String {
        """
        [features]
        hooks = true

        # Notchly Codex alerts
        [[hooks.Stop]]
        [[hooks.Stop.hooks]]
        type = "command"
        command = '\(completedHookCommand)'

        [[hooks.PermissionRequest]]
        [[hooks.PermissionRequest.hooks]]
        type = "command"
        command = '\(approvalHookCommand)'
        """
    }

    func refreshStatus() {
        installState = isHookInstalled() ? .installed : .notInstalled
    }

    func install() {
        installState = .installing

        do {
            try installHookScript()
            try updateCodexConfig()
            refreshStatus()
        } catch {
            installState = .failed(error.localizedDescription)
        }
    }

    private func installHookScript() throws {
        try fileManager.createDirectory(
            at: hookDirectoryURL,
            withIntermediateDirectories: true
        )

        try hookScript.write(to: hookScriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: hookScriptURL.path
        )
    }

    private func updateCodexConfig() throws {
        try fileManager.createDirectory(
            at: codexConfigDirectoryURL,
            withIntermediateDirectories: true
        )

        var config = ""
        if fileManager.fileExists(atPath: codexConfigURL.path) {
            config = try String(contentsOf: codexConfigURL, encoding: .utf8)
        }

        config = enableCodexHooks(in: config)
        config = removeManagedHookBlocks(from: config)

        config = appendHookBlockIfNeeded(
            to: config,
            eventName: "Stop",
            command: completedHookCommand
        )

        config = appendHookBlockIfNeeded(
            to: config,
            eventName: "PermissionRequest",
            command: approvalHookCommand
        )

        try config.write(to: codexConfigURL, atomically: true, encoding: .utf8)
    }

    private func removeManagedHookBlocks(from config: String) -> String {
        let lines = config.components(separatedBy: .newlines)
        var keptLines: [String] = []
        var pendingBlock: [String] = []
        var isCapturingHookBlock = false

        func flushPendingBlock() {
            guard !pendingBlock.isEmpty else { return }

            if pendingBlock.joined(separator: "\n").contains(hookScriptURL.path) {
                pendingBlock.removeAll()
                return
            }

            keptLines.append(contentsOf: pendingBlock)
            pendingBlock.removeAll()
        }

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let isHookHeader = trimmedLine.hasPrefix("[[hooks.")

            if isHookHeader {
                flushPendingBlock()
                isCapturingHookBlock = true
                pendingBlock.append(line)
                continue
            }

            if isCapturingHookBlock {
                let startsRegularTable = trimmedLine.hasPrefix("[") &&
                    trimmedLine.hasSuffix("]") &&
                    !trimmedLine.hasPrefix("[[")

                if startsRegularTable {
                    flushPendingBlock()
                    isCapturingHookBlock = false
                    keptLines.append(line)
                } else {
                    pendingBlock.append(line)
                }
                continue
            }

            keptLines.append(line)
        }

        flushPendingBlock()

        return keptLines
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }

    private func appendHookBlockIfNeeded(to config: String, eventName: String, command: String) -> String {
        guard !containsHookCommand(config, eventName: eventName, command: command) else { return config }

        var updatedConfig = config
        if !updatedConfig.isEmpty, !updatedConfig.hasSuffix("\n") {
            updatedConfig += "\n"
        }

        if !updatedConfig.contains("# Notchly Codex alerts") {
            updatedConfig += "\n# Notchly Codex alerts\n"
        }

        updatedConfig += """
[[hooks.\(eventName)]]
[[hooks.\(eventName).hooks]]
type = "command"
command = '\(command)'
"""
        updatedConfig += "\n"
        return updatedConfig
    }

    private func containsHookCommand(_ config: String, eventName: String, command: String) -> Bool {
        let eventHeader = "[[hooks.\(eventName)]]"
        let handlerHeader = "[[hooks.\(eventName).hooks]]"
        var isInsideEvent = false

        for line in config.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine == eventHeader || trimmedLine == handlerHeader {
                isInsideEvent = true
                continue
            }

            if trimmedLine.hasPrefix("[[hooks."),
               trimmedLine != eventHeader,
               trimmedLine != handlerHeader {
                isInsideEvent = false
            }

            if isInsideEvent, trimmedLine.contains(command) {
                return true
            }
        }

        return false
    }

    private func enableCodexHooks(in config: String) -> String {
        var lines = config.components(separatedBy: .newlines)

        guard let featuresIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "[features]" }) else {
            if !lines.isEmpty, lines.last?.isEmpty == false {
                lines.append("")
            }
            lines.append("[features]")
            lines.append("hooks = true")
            return lines.joined(separator: "\n")
        }

        var sectionEndIndex = lines.index(after: featuresIndex)
        while sectionEndIndex < lines.endIndex {
            let trimmedLine = lines[sectionEndIndex].trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                break
            }
            sectionEndIndex = lines.index(after: sectionEndIndex)
        }

        if let existingIndex = lines[lines.index(after: featuresIndex)..<sectionEndIndex]
            .firstIndex(where: {
                let trimmedLine = $0.trimmingCharacters(in: .whitespaces)
                return trimmedLine.hasPrefix("hooks") || trimmedLine.hasPrefix("codex_hooks")
            }) {
            lines[existingIndex] = "hooks = true"
        } else {
            lines.insert("hooks = true", at: sectionEndIndex)
        }

        return lines.joined(separator: "\n")
    }

    private func isHookInstalled() -> Bool {
        guard fileManager.isExecutableFile(atPath: hookScriptURL.path),
              let config = try? String(contentsOf: codexConfigURL, encoding: .utf8) else {
            return false
        }

        return config.contains("hooks = true") &&
            config.contains(completedHookCommand) &&
            containsHookCommand(config, eventName: "PermissionRequest", command: approvalHookCommand)
    }

    private var completedHookCommand: String {
        "\"\(hookScriptURL.path)\" completed"
    }

    private var approvalHookCommand: String {
        "\"\(hookScriptURL.path)\" approval"
    }

    private var hookScript: String {
        """
#!/bin/sh
set -eu

event_type="${1:-completed}"
events_dir="$HOME/Library/Application Support/Notchly"
events_file="$events_dir/agent-events.jsonl"

mkdir -p "$events_dir"

case "$event_type" in
  completed|stop)
    type="completed"
    title="Job is done"
    message="Codex finished"
    ;;
  failed)
    type="failed"
    title="Task failed"
    message="Codex failed"
    ;;
  approval|access_request|notification|permission_request)
    type="access_request"
    title="Need approval"
    message="Codex is awaiting approval"
    ;;
  *)
    type="completed"
    title="Job is done"
    message="Codex finished"
    ;;
esac

printf '{"source":"codex","type":"%s","title":"%s","message":"%s","ttl":3}\\n' "$type" "$title" "$message" >> "$events_file"
"""
    }

    private var codexConfigDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }

    private var codexConfigURL: URL {
        codexConfigDirectoryURL.appendingPathComponent("config.toml")
    }

    private var hookDirectoryURL: URL {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notchly", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
    }

    private var hookScriptURL: URL {
        hookDirectoryURL.appendingPathComponent("notchly-codex-hook")
    }
}
