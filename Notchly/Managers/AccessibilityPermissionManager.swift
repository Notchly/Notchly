//
//  AccessibilityPermissionManager.swift
//  Notchly
//
//  Created by user on 29.05.2026.
//

import AppKit
import ApplicationServices

enum AccessibilityPermissionManager {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccess() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
