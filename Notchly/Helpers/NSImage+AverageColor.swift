//
//  NSImage+AverageColor.swift
//  DynamicIsland
//
//  Created by n0xbyte on 19.03.2026.
//

import AppKit

struct PreparedArtworkImages: @unchecked Sendable {
    let displayImage: CGImage
    let wallpaperImage: CGImage
    let averageColor: ArtworkAverageColor?
}

struct ArtworkAverageColor: Sendable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}

nonisolated enum ArtworkImageProcessor {
    static func prepare(_ sourceImage: CGImage) -> PreparedArtworkImages {
        let displayImage = resized(sourceImage, maximumPixelSize: 96)
        let wallpaperImage = resized(sourceImage, maximumPixelSize: 1600)

        return PreparedArtworkImages(
            displayImage: displayImage,
            wallpaperImage: wallpaperImage,
            averageColor: averageColor(of: displayImage)
        )
    }

    private static func resized(_ sourceImage: CGImage, maximumPixelSize: CGFloat) -> CGImage {
        let sourceSize = CGSize(width: sourceImage.width, height: sourceImage.height)
        let longestSide = max(sourceSize.width, sourceSize.height)
        guard longestSide > maximumPixelSize else { return sourceImage }

        let scale = maximumPixelSize / longestSide
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )

        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return sourceImage
        }

        context.interpolationQuality = .high
        context.draw(sourceImage, in: CGRect(origin: .zero, size: targetSize))
        return context.makeImage() ?? sourceImage
    }

    private static func averageColor(of image: CGImage) -> ArtworkAverageColor? {
        var bitmap = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &bitmap,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return ArtworkAverageColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0
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
