//
//  WindowScreenReader.swift
//  Notchly
//
//  Created by user on 20.04.2026.
//

import SwiftUI
import AppKit

struct WindowScreenReader: NSViewRepresentable {
    let onUpdate: (NSScreen?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScreenAwareView()
        view.onScreenChange = onUpdate
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ScreenAwareView else { return }
        view.onScreenChange = onUpdate

        DispatchQueue.main.async {
            view.notifyCurrentScreen()
        }
    }
}

final class ScreenAwareView: NSView {
    var onScreenChange: ((NSScreen?) -> Void)?
    private var hasPendingScreenNotification = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        subscribeToWindowChanges()
        notifyCurrentScreen()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        notifyCurrentScreen()
    }

    func notifyCurrentScreen() {
        guard !hasPendingScreenNotification else { return }
        hasPendingScreenNotification = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hasPendingScreenNotification = false
            self.onScreenChange?(self.window?.screen)
        }
    }

    private func subscribeToWindowChanges() {
        NotificationCenter.default.removeObserver(self)

        guard let window else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeScreen),
            name: NSWindow.didChangeScreenNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidChangeScreenProfile),
            name: NSWindow.didChangeScreenProfileNotification,
            object: window
        )
    }

    @objc private func windowDidMove() {
        notifyCurrentScreen()
    }

    @objc private func windowDidResize() {
        notifyCurrentScreen()
    }

    @objc private func windowDidChangeScreen() {
        notifyCurrentScreen()
    }

    @objc private func windowDidChangeScreenProfile() {
        notifyCurrentScreen()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
