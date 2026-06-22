//
//  MarqueeText.swift
//  Notchly
//
//  Created by n0xbyte on 24.03.2026.
//

import SwiftUI
import AppKit

struct MarqueeText: View {
    let text: String
    let font: Font
    let nsFont: NSFont
    let color: NSColor
    let speed: Double
    let maxLength: Int?
    let maxRenderWidth: CGFloat?

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offsetX: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    init(
        text: String,
        font: Font,
        nsFont: NSFont,
        color: NSColor,
        speed: Double,
        maxLength: Int? = nil,
        maxRenderWidth: CGFloat? = nil
    ) {
        self.text = text
        self.font = font
        self.nsFont = nsFont
        self.color = color
        self.speed = speed
        self.maxLength = maxLength
        self.maxRenderWidth = maxRenderWidth
    }

    private var displayText: String {
        var value = text

        if let maxLength, value.count > maxLength {
            value = String(value.prefix(maxLength)) + "…"
        }

        if let maxRenderWidth {
            value = truncateToFitWidth(value, maxWidth: maxRenderWidth, font: nsFont)
        }

        return value
    }

    var body: some View {
        GeometryReader { geo in
            let renderedText = displayText

            ZStack(alignment: .leading) {
                Text(renderedText)
                    .font(font)
                    .foregroundStyle(Color(nsColor: color))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: offsetX)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear {
                                    updateMeasuredSizes(
                                        textWidth: proxy.size.width,
                                        containerWidth: geo.size.width,
                                        forceRestart: true
                                    )
                                }
                                .onChange(of: proxy.size.width) { _, newValue in
                                    updateMeasuredSizes(
                                        textWidth: newValue,
                                        containerWidth: geo.size.width
                                    )
                                }
                                .onChange(of: renderedText) { _, _ in
                                    updateMeasuredSizes(
                                        textWidth: proxy.size.width,
                                        containerWidth: geo.size.width,
                                        forceRestart: true
                                    )
                                }
                        }
                    )
            }
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func updateMeasuredSizes(
        textWidth nextTextWidth: CGFloat,
        containerWidth nextContainerWidth: CGFloat,
        forceRestart: Bool = false
    ) {
        let changed =
            abs(textWidth - nextTextWidth) > 0.5 ||
            abs(containerWidth - nextContainerWidth) > 0.5

        guard changed || forceRestart else { return }

        textWidth = nextTextWidth
        containerWidth = nextContainerWidth
        startAnimation()
    }

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = nil

        guard textWidth > containerWidth, containerWidth > 0 else {
            if offsetX != 0 {
                offsetX = 0
            }
            return
        }

        offsetX = 0

        let distance = textWidth - containerWidth + 20
        let duration = distance / speed

        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }

                withAnimation(.linear(duration: duration)) {
                    offsetX = -distance
                }

                try? await Task.sleep(for: .seconds(duration + 0.6))
                guard !Task.isCancelled else { return }

                offsetX = 0
            }
        }
    }

    private func truncateToFitWidth(_ text: String, maxWidth: CGFloat, font: NSFont) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]

        if (text as NSString).size(withAttributes: attributes).width <= maxWidth {
            return text
        }

        let ellipsis = "…"
        let characters = Array(text)
        guard !characters.isEmpty else { return ellipsis }

        var low = 0
        var high = max(0, characters.count - 1)

        while low < high {
            let mid = (low + high + 1) / 2
            let candidate = String(characters.prefix(mid)) + ellipsis
            if (candidate as NSString).size(withAttributes: attributes).width <= maxWidth {
                low = mid
            } else {
                high = mid - 1
            }
        }

        let candidate = String(characters.prefix(low)) + ellipsis
        return (candidate as NSString).size(withAttributes: attributes).width <= maxWidth ? candidate : ellipsis
    }
}
