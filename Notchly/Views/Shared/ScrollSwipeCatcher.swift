//
//  ScrollSwipeCatcher.swift
//  Notchly
//
//  Created by user on 24.03.2026.
//

import SwiftUI
import AppKit

struct ScrollSwipeCatcher: NSViewRepresentable {
    var onScroll: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollTrackingView {
        let view = ScrollTrackingView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollTrackingView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollTrackingView: NSView {
    var onScroll: ((CGFloat, CGFloat) -> Void)?

    private var scrollMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    deinit {
        removeMonitor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        removeMonitor()

        guard window != nil else { return }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            guard let window = self.window else { return event }
            guard !self.isHidden, self.alphaValue > 0 else { return event }

            let pointInWindow = window.mouseLocationOutsideOfEventStream
            let pointInView = self.convert(pointInWindow, from: nil)

            guard self.bounds.contains(pointInView) else { return event }

            self.onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
            return event
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func removeMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
    }
}
