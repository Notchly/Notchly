//
//  WindowScreenReader.swift
//  Notchly
//
//  Created by n0xbyte on 20.04.2026.
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
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        guard let view = nsView as? ScreenAwareView else { return }
        view.prepareForRemoval()
    }
}

final class ScreenAwareView: NSView {
    var onScreenChange: ((NSScreen?) -> Void)?
    private weak var observedWindow: NSWindow?
    private weak var lastNotifiedScreen: NSScreen?
    private var hasPendingScreenNotification = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        subscribeToWindowChanges()
        scheduleScreenNotification()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        scheduleScreenNotification()
    }

    func scheduleScreenNotification() {
        guard !hasPendingScreenNotification else { return }
        hasPendingScreenNotification = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hasPendingScreenNotification = false
            self.flushScreenNotification()
        }
    }

    private func subscribeToWindowChanges() {
        guard observedWindow !== window else { return }

        unsubscribeFromWindowChanges()

        guard let window else { return }
        observedWindow = window

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

    private func unsubscribeFromWindowChanges() {
        guard let observedWindow else {
            NotificationCenter.default.removeObserver(self)
            return
        }

        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didMoveNotification,
            object: observedWindow
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didResizeNotification,
            object: observedWindow
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didChangeScreenNotification,
            object: observedWindow
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didChangeScreenProfileNotification,
            object: observedWindow
        )

        self.observedWindow = nil
    }

    private func flushScreenNotification() {
        let screen = window?.screen
        guard lastNotifiedScreen !== screen else { return }

        lastNotifiedScreen = screen
        onScreenChange?(screen)
    }

    func prepareForRemoval() {
        hasPendingScreenNotification = false
        lastNotifiedScreen = nil
        onScreenChange = nil
        unsubscribeFromWindowChanges()
    }

    @objc private func windowDidMove() {
        scheduleScreenNotification()
    }

    @objc private func windowDidResize() {
        scheduleScreenNotification()
    }

    @objc private func windowDidChangeScreen() {
        scheduleScreenNotification()
    }

    @objc private func windowDidChangeScreenProfile() {
        scheduleScreenNotification()
    }

    deinit {
        prepareForRemoval()
    }
}
