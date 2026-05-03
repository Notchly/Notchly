//
//  IslandClickCatcher.swift
//  Notchly
//
//  Created by user on 03.04.2026.
//

import SwiftUI
import AppKit

struct IslandClickCatcher: NSViewRepresentable {
    let onClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onClick: onClick)
    }

    func makeNSView(context: Context) -> NSView {
        let view = ClickCatcherNSView()
        view.onClick = context.coordinator.handleClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? ClickCatcherNSView else { return }
        view.onClick = context.coordinator.handleClick
    }

    final class Coordinator {
        let onClick: () -> Void

        init(onClick: @escaping () -> Void) {
            self.onClick = onClick
        }

        @objc func handleClick() {
            onClick()
        }
    }
}

final class ClickCatcherNSView: NSView {
    var onClick: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
