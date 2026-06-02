//
//  NSImage+AverageColor.swift
//  DynamicIsland
//
//  Created by user on 19.03.2026.
//

import AppKit
import SwiftUI

extension NSImage {
    func resizedForArtwork(maxPixelSize: CGFloat = 96) -> NSImage {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return self
        }

        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let longestSide = max(sourceSize.width, sourceSize.height)
        guard longestSide > maxPixelSize else {
            cacheMode = .never
            return self
        }

        let scale = maxPixelSize / longestSide
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )

        let targetRect = CGRect(origin: .zero, size: targetSize)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return self
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: targetRect)

        guard let resizedCGImage = context.makeImage() else {
            return self
        }

        let image = NSImage(cgImage: resizedCGImage, size: targetSize)
        image.cacheMode = .never
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

}
