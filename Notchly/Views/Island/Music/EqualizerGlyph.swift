//
//  EqualizerGlyph.swift
//  Notchly
//
//  Created by user on 14.05.2026.
//

import SwiftUI
import AppKit

struct EqualizerGlyph: NSViewRepresentable {
    let isActive: Bool
    let color: Color
    let idleHeights: [CGFloat]
    let activeHeights: [CGFloat]
    let phaseOffsets: [Double]
    let barWidth: CGFloat
    let spacing: CGFloat
    let speed: Double

    init(
        isActive: Bool,
        color: Color = .white,
        idleHeights: [CGFloat] = [4, 6, 5, 7, 4],
        activeHeights: [CGFloat] = [10, 13, 9, 12, 8],
        phaseOffsets: [Double] = [0.0, 1.3, 2.4, 0.7, 1.9],
        barWidth: CGFloat = 2,
        spacing: CGFloat = 2,
        speed: Double = 5.4
    ) {
        self.isActive = isActive
        self.color = color
        self.idleHeights = idleHeights
        self.activeHeights = activeHeights
        self.phaseOffsets = phaseOffsets
        self.barWidth = barWidth
        self.spacing = spacing
        self.speed = speed
    }

    func makeNSView(context: Context) -> EqualizerGlyphNSView {
        let view = EqualizerGlyphNSView()
        view.update(
            isActive: isActive,
            color: NSColor(color),
            idleHeights: idleHeights,
            activeHeights: activeHeights,
            phaseOffsets: phaseOffsets,
            barWidth: barWidth,
            spacing: spacing,
            speed: speed
        )
        return view
    }

    func updateNSView(_ nsView: EqualizerGlyphNSView, context: Context) {
        nsView.update(
            isActive: isActive,
            color: NSColor(color),
            idleHeights: idleHeights,
            activeHeights: activeHeights,
            phaseOffsets: phaseOffsets,
            barWidth: barWidth,
            spacing: spacing,
            speed: speed
        )
    }
}

final class EqualizerGlyphNSView: NSView {
    private var barLayers: [CALayer] = []
    private var idleHeights: [CGFloat] = []
    private var activeHeights: [CGFloat] = []
    private var phaseOffsets: [Double] = []
    private var barWidth: CGFloat = 2
    private var spacing: CGFloat = 2
    private var speed: Double = 5.4
    private var currentColor: NSColor = .white
    private var currentlyActive = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false
    }

    deinit {
        barLayers.forEach { $0.removeAllAnimations() }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: totalWidth, height: maxHeight)
    }

    override func layout() {
        super.layout()

        layoutBars()
    }

    private func layoutBars() {
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.midY

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (index, layer) in barLayers.enumerated() {
            let height = activeHeights[index]
            let x = startX + CGFloat(index) * (barWidth + spacing)
            let scale = inactiveScale(at: index)

            layer.bounds = CGRect(x: 0, y: 0, width: barWidth, height: height)
            layer.position = CGPoint(x: x + barWidth / 2, y: centerY)
            layer.cornerRadius = barWidth / 2

            if !currentlyActive {
                layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: scale))
            }
        }

        CATransaction.commit()
    }

    func update(
        isActive: Bool,
        color: NSColor,
        idleHeights: [CGFloat],
        activeHeights: [CGFloat],
        phaseOffsets: [Double],
        barWidth: CGFloat,
        spacing: CGFloat,
        speed: Double
    ) {
        let nextBarCount = min(idleHeights.count, activeHeights.count)
        let geometryChanged =
            self.idleHeights != Array(idleHeights.prefix(nextBarCount)) ||
            self.activeHeights != Array(activeHeights.prefix(nextBarCount)) ||
            self.phaseOffsets != phaseOffsets ||
            self.barWidth != barWidth ||
            self.spacing != spacing ||
            self.speed != speed

        self.idleHeights = Array(idleHeights.prefix(nextBarCount))
        self.activeHeights = Array(activeHeights.prefix(nextBarCount))
        self.phaseOffsets = phaseOffsets
        self.barWidth = barWidth
        self.spacing = spacing
        self.speed = speed

        if barLayers.count != nextBarCount {
            rebuildBars(count: nextBarCount)
        }

        if currentColor != color {
            currentColor = color
            updateBarColors()
        }

        if geometryChanged {
            invalidateIntrinsicContentSize()
            needsLayout = true
            if currentlyActive {
                startAnimating()
            }
        }

        guard currentlyActive != isActive else { return }
        currentlyActive = isActive

        if isActive {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    private var totalWidth: CGFloat {
        guard !barLayers.isEmpty else { return 0 }
        return (CGFloat(barLayers.count) * barWidth) + (CGFloat(barLayers.count - 1) * spacing)
    }

    private var maxHeight: CGFloat {
        activeHeights.max() ?? 0
    }

    private func rebuildBars(count: Int) {
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers = []

        guard let rootLayer = layer else { return }

        for index in 0..<count {
            let bar = CALayer()
            bar.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            bar.backgroundColor = barColor(at: index).cgColor
            rootLayer.addSublayer(bar)
            barLayers.append(bar)
        }

        needsLayout = true
    }

    private func updateBarColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (index, layer) in barLayers.enumerated() {
            layer.backgroundColor = barColor(at: index).cgColor
        }

        CATransaction.commit()
    }

    private func startAnimating() {
        layoutBars()

        for (index, layer) in barLayers.enumerated() {
            layer.removeAnimation(forKey: "equalizer")

            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = inactiveScale(at: index)
            animation.toValue = 1.0
            animation.duration = animationDuration(at: index)
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.beginTime = CACurrentMediaTime() + phaseDelay(at: index)
            animation.isRemovedOnCompletion = false

            layer.add(animation, forKey: "equalizer")
        }
    }

    private func stopAnimating() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (index, layer) in barLayers.enumerated() {
            layer.removeAnimation(forKey: "equalizer")
            layer.setAffineTransform(CGAffineTransform(scaleX: 1, y: inactiveScale(at: index)))
        }

        CATransaction.commit()
    }

    private func inactiveScale(at index: Int) -> CGFloat {
        guard index < idleHeights.count, index < activeHeights.count, activeHeights[index] > 0 else {
            return 0.35
        }

        return min(max(idleHeights[index] / activeHeights[index], 0.2), 1)
    }

    private func animationDuration(at index: Int) -> TimeInterval {
        let baseDuration = max(0.38, min(1.2, 4.2 / max(speed, 0.1)))
        return baseDuration + (Double(index) * 0.07)
    }

    private func phaseDelay(at index: Int) -> TimeInterval {
        let phase = index < phaseOffsets.count ? phaseOffsets[index] : Double(index) * 0.73
        return phase * 0.035
    }

    private func barColor(at index: Int) -> NSColor {
        index == 0 ? currentColor.withAlphaComponent(currentColor.alphaComponent * 0.6) : currentColor
    }
}
