//
//  MarqueeText.swift
//  Notchly
//
//  Created by user on 24.03.2026.
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
            ZStack(alignment: .leading) {
                Text(displayText)
                    .font(font)
                    .foregroundStyle(Color(nsColor: color))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: offsetX)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear {
                                    textWidth = proxy.size.width
                                    containerWidth = geo.size.width
                                    startAnimation()
                                }
                                .onChange(of: proxy.size.width) { _, newValue in
                                    textWidth = newValue
                                    containerWidth = geo.size.width
                                    startAnimation()
                                }
                                .onChange(of: displayText) { _, _ in
                                    textWidth = proxy.size.width
                                    containerWidth = geo.size.width
                                    startAnimation()
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

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = nil

        guard textWidth > containerWidth, containerWidth > 0 else {
            offsetX = 0
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
        var result = text

        while !result.isEmpty {
            let candidate = String(result.dropLast()) + ellipsis
            if (candidate as NSString).size(withAttributes: attributes).width <= maxWidth {
                return candidate
            }
            result = String(result.dropLast())
        }

        return ellipsis
    }
}
