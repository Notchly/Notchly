//
//  AnimatedWaveformView.swift
//  Notchly
//
//  Created by user on 19.03.2026.
//

import SwiftUI
import AppKit

struct AnimatedWaveformView: NSViewRepresentable {
    let isPlaying: Bool
    let color: NSColor

    func makeNSView(context: Context) -> WaveformNSView {
        let view = WaveformNSView()
        view.update(isPlaying: isPlaying, color: color)
        return view
    }

    func updateNSView(_ nsView: WaveformNSView, context: Context) {
        nsView.update(isPlaying: isPlaying, color: color)
    }
}

final class WaveformNSView: NSView {
    private let barCount = 6
    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 3
    private let baseHeights: [CGFloat] = [8, 14, 10, 16, 11, 9]

    private var barLayers: [CALayer] = []
    private var currentColor: NSColor = .systemGreen
    private var currentlyPlaying = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false
        setupBars()
    }

    override var intrinsicContentSize: NSSize {
        let width = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        return NSSize(width: width, height: 18)
    }

    override func layout() {
        super.layout()

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.midY

        for (index, layer) in barLayers.enumerated() {
            let height = baseHeights[index]
            let x = startX + CGFloat(index) * (barWidth + spacing)
            let y = centerY - height / 2

            layer.bounds = CGRect(x: 0, y: 0, width: barWidth, height: height)
            layer.position = CGPoint(x: x + barWidth / 2, y: y + height / 2)
            layer.cornerRadius = barWidth / 2
        }
    }

    func update(isPlaying: Bool, color: NSColor) {
        if currentColor != color {
            currentColor = color
            for layer in barLayers {
                layer.backgroundColor = color.cgColor
            }
        }

        guard currentlyPlaying != isPlaying else { return }
        currentlyPlaying = isPlaying

        if isPlaying {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    private func setupBars() {
        guard let rootLayer = layer else { return }

        for _ in 0..<barCount {
            let bar = CALayer()
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            bar.backgroundColor = currentColor.cgColor
            rootLayer.addSublayer(bar)
            barLayers.append(bar)
        }
    }

    private func startAnimating() {
        let minScales: [CGFloat] = [0.42, 0.28, 0.52, 0.34, 0.46, 0.38]

        for (index, layer) in barLayers.enumerated() {
            layer.removeAllAnimations()

            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = minScales[index]
            animation.toValue = 1.0
            animation.duration = 0.9 + Double(index) * 0.12
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.beginTime = CACurrentMediaTime() + Double(index) * 0.06
            animation.isRemovedOnCompletion = false

            layer.add(animation, forKey: "wave")
        }
    }

    private func stopAnimating() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for layer in barLayers {
            layer.removeAnimation(forKey: "wave")
            layer.setAffineTransform(.identity.scaledBy(x: 1, y: 0.35))
        }

        CATransaction.commit()
    }
}
