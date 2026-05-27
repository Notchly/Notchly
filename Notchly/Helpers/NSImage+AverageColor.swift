//
//  NSImage+AverageColor.swift
//  DynamicIsland
//
//  Created by user on 19.03.2026.
//

import AppKit
import SwiftUI

extension NSImage {
    func resizedForArtwork(maxPixelSize: CGFloat = 256) -> NSImage {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return self
        }

        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let longestSide = max(sourceSize.width, sourceSize.height)
        guard longestSide > maxPixelSize else { return self }

        let scale = maxPixelSize / longestSide
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )

        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: CGRect(origin: .zero, size: targetSize))
        image.unlockFocus()
        return image
    }

    var averageColor: NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bitmap,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return NSColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1
        )
    }

    var lockScreenBackdropColors: [NSColor] {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return [
                NSColor(white: 0.18, alpha: 1),
                NSColor(white: 0.08, alpha: 1)
            ]
        }

        let sampleSize = 24
        var bitmap = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bitmap,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return averageColor.map { [$0.lockScreenNeutralized, $0.lockScreenCompanion] } ?? [
                NSColor(white: 0.18, alpha: 1),
                NSColor(white: 0.08, alpha: 1)
            ]
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var hueBuckets: [Int: (weight: CGFloat, hue: CGFloat, saturation: CGFloat, brightness: CGFloat)] = [:]
        var totalSaturation: CGFloat = 0
        var totalBrightness: CGFloat = 0
        var sampleCount: CGFloat = 0

        stride(from: 0, to: bitmap.count, by: 4).forEach { index in
            let red = CGFloat(bitmap[index]) / 255
            let green = CGFloat(bitmap[index + 1]) / 255
            let blue = CGFloat(bitmap[index + 2]) / 255
            let color = NSColor(red: red, green: green, blue: blue, alpha: 1)

            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            totalSaturation += saturation
            totalBrightness += brightness
            sampleCount += 1

            guard saturation > 0.16, brightness > 0.10, brightness < 0.94 else { return }

            let bucket = Int((hue * 18).rounded(.down))
            let weight = max(0.08, saturation) * (0.35 + min(brightness, 0.8))
            let current = hueBuckets[bucket] ?? (0, 0, 0, 0)
            let nextWeight = current.weight + weight

            hueBuckets[bucket] = (
                weight: nextWeight,
                hue: ((current.hue * current.weight) + (hue * weight)) / nextWeight,
                saturation: ((current.saturation * current.weight) + (saturation * weight)) / nextWeight,
                brightness: ((current.brightness * current.weight) + (brightness * weight)) / nextWeight
            )
        }

        let averageSaturation = sampleCount > 0 ? totalSaturation / sampleCount : 0
        let averageBrightness = sampleCount > 0 ? totalBrightness / sampleCount : 0.24

        guard averageSaturation > 0.12 else {
            let baseWhite = min(max(averageBrightness * 0.42, 0.18), 0.42)
            return [
                NSColor(white: baseWhite, alpha: 1),
                NSColor(white: max(baseWhite * 0.48, 0.08), alpha: 1)
            ]
        }

        let colors = hueBuckets.values
            .sorted { $0.weight > $1.weight }
            .prefix(2)
            .map { bucket in
                NSColor(
                    hue: bucket.hue,
                    saturation: min(max(bucket.saturation * 0.84, 0.18), 0.58),
                    brightness: min(max(bucket.brightness * 0.72, 0.18), 0.46),
                    alpha: 1
                )
            }

        if colors.count >= 2 {
            return Array(colors)
        }

        if let color = colors.first {
            return [color, color.lockScreenCompanion]
        }

        return averageColor.map { [$0.lockScreenNeutralized, $0.lockScreenCompanion] } ?? [
            NSColor(white: 0.18, alpha: 1),
            NSColor(white: 0.08, alpha: 1)
        ]
    }
}

extension NSColor {
    var boostedForWaveform: NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.12 {
            let white = min(max(brightness, 0.72), 0.92)
            return NSColor(white: white, alpha: 1)
        }

        return NSColor(
            hue: hue,
            saturation: max(0.55, saturation),
            brightness: max(0.75, brightness),
            alpha: 1
        )
    }

    var lockScreenNeutralized: NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.12 {
            return NSColor(
                white: min(max(brightness * 0.42, 0.18), 0.42),
                alpha: 1
            )
        }

        return NSColor(
            hue: hue,
            saturation: min(max(saturation * 0.84, 0.18), 0.58),
            brightness: min(max(brightness * 0.72, 0.18), 0.46),
            alpha: 1
        )
    }

    var lockScreenCompanion: NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.12 {
            return NSColor(
                white: max(min(brightness * 0.22, 0.24), 0.08),
                alpha: 1
            )
        }

        return NSColor(
            hue: (hue + 0.08).truncatingRemainder(dividingBy: 1),
            saturation: min(max(saturation * 0.62, 0.16), 0.46),
            brightness: min(max(brightness * 0.42, 0.10), 0.28),
            alpha: 1
        )
    }
}
