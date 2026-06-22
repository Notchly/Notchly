//
//  CursorHookIntegrationManager.swift
//  Notchly
//
//  Created by n0xbyte on 03.06.2026.
//

import Foundation
import Combine

@MainActor
final class CursorHookIntegrationManager: ObservableObject {
    @Published private(set) var installState: AgentHookInstallState = .unknown

    private let fileManager = FileManager.default

    var isInstalled: Bool {
        if case .installed = installState {
            return true
        }
        return false
    }

    var configPreview: String {
        """
        {
          "version": 1,
          "hooks": {
            "stop": [
              { "command": "\(completedHookCommand)" }
            ]
          }
        }
        """
    }

    func refreshStatus() {
        installState = isHookInstalled() ? .installed : .notInstalled
    }

    func install() {
        installState = .installing

        do {
            try installHookScript()
            try updateCursorConfig()
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

    private func updateCursorConfig() throws {
        try fileManager.createDirectory(
            at: cursorConfigDirectoryURL,
            withIntermediateDirectories: true
        )

        var config = try loadCursorConfig()
        config["version"] = config["version"] ?? 1

        var hooks = config["hooks"] as? [String: Any] ?? [:]
        hooks = removeManagedHookCommands(from: hooks)
        hooks = appendHookCommand(to: hooks, eventName: "stop", command: completedHookCommand)
        config["hooks"] = hooks

        let data = try JSONSerialization.data(
            withJSONObject: config,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: cursorConfigURL, options: .atomic)
    }

    private func loadCursorConfig() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: cursorConfigURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: cursorConfigURL)
        guard !data.isEmpty else {
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let config = object as? [String: Any] else {
            throw NSError(
                domain: "CursorHookIntegrationManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cursor hooks.json must contain a JSON object."]
            )
        }

        return config
    }

    private func removeManagedHookCommands(from hooks: [String: Any]) -> [String: Any] {
        var updatedHooks: [String: Any] = [:]

        for (eventName, value) in hooks {
            guard let hookEntries = value as? [[String: Any]] else {
                updatedHooks[eventName] = value
                continue
            }

            let filteredEntries = hookEntries.filter { entry in
                guard let command = entry["command"] as? String else { return true }
                return !command.contains(hookScriptURL.path)
            }

            if !filteredEntries.isEmpty {
                updatedHooks[eventName] = filteredEntries
            }
        }

        return updatedHooks
    }

    private func appendHookCommand(
        to hooks: [String: Any],
        eventName: String,
        command: String
    ) -> [String: Any] {
        var updatedHooks = hooks
        var hookEntries = updatedHooks[eventName] as? [[String: Any]] ?? []

        guard !hookEntries.contains(where: { ($0["command"] as? String) == command }) else {
            return updatedHooks
        }

        hookEntries.append(["command": command])
        updatedHooks[eventName] = hookEntries
        return updatedHooks
    }

    private func isHookInstalled() -> Bool {
        guard fileManager.isExecutableFile(atPath: hookScriptURL.path),
              let config = try? loadCursorConfig(),
              let hooks = config["hooks"] as? [String: Any] else {
            return false
        }

        return containsHookCommand(hooks, eventName: "stop", command: completedHookCommand)
    }

    private func containsHookCommand(
        _ hooks: [String: Any],
        eventName: String,
        command: String
    ) -> Bool {
        guard let hookEntries = hooks[eventName] as? [[String: Any]] else { return false }
        return hookEntries.contains { ($0["command"] as? String) == command }
    }

    private var completedHookCommand: String {
        "\"\(hookScriptURL.path)\" completed"
    }

    private var approvalHookCommand: String {
        "\"\(hookScriptURL.path)\" approval"
    }

    private var approvedHookCommand: String {
        "\"\(hookScriptURL.path)\" approved"
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
    title="Task completed"
    message="Cursor finished"
    ;;
  failed)
    type="failed"
    title="Task failed"
    message="Cursor failed"
    ;;
  approval|access_request|notification|permission_request|before_shell_command|before_shell_execution)
    type="access_request"
    title="Need approval"
    message="Cursor is awaiting approval"
    ;;
  approved|clear|after_shell_command|after_shell_execution)
    type="clear"
    title=""
    message=""
    ;;
  *)
    type="completed"
    title="Task completed"
    message="Cursor finished"
    ;;
esac

printf '{"source":"cursor","type":"%s","title":"%s","message":"%s","ttl":3}\\n' "$type" "$title" "$message" >> "$events_file"
"""
    }

    private var cursorConfigDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor", isDirectory: true)
    }

    private var cursorConfigURL: URL {
        cursorConfigDirectoryURL.appendingPathComponent("hooks.json")
    }

    private var hookDirectoryURL: URL {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notchly", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
    }

    private var hookScriptURL: URL {
        hookDirectoryURL.appendingPathComponent("notchly-cursor-hook")
    }
}
