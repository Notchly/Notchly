//
//  LockScreenWallpaperManager.swift
//  Notchly
//

import AppKit
import CoreImage
import ImageIO

@MainActor
final class LockScreenWallpaperManager {
    private struct OriginalWallpaper {
        let url: URL
        let options: [NSWorkspace.DesktopImageOptionKey: Any]
        let displayID: CGDirectDisplayID?
    }

    private struct RecoveryRecord: Codable {
        let url: String
        let displayID: UInt32?
    }

    private let workspace = NSWorkspace.shared
    private let renderer = LockScreenBackdropRenderer(maximumSide: 2560)
    private let renderQueue = DispatchQueue(
        label: "xyz.notchly.lock-screen-wallpaper",
        qos: .userInitiated
    )
    private let fileManager = FileManager.default
    private let workingDirectoryURL: URL
    private let recoveryURL: URL
    private var originalWallpaper: OriginalWallpaper?
    private var activeArtworkURL: URL?
    private var cleanupTask: DispatchWorkItem?
    private var operationID = UUID()

    init() {
        let applicationSupport = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        workingDirectoryURL = applicationSupport
            .appendingPathComponent("Notchly/LockScreenWallpaper", isDirectory: true)
        recoveryURL = workingDirectoryURL.appendingPathComponent("restore.json")
    }

    func recoverSynchronously() {
        guard let data = try? Data(contentsOf: recoveryURL),
              let record = try? JSONDecoder().decode(RecoveryRecord.self, from: data),
              let originalURL = URL(string: record.url),
              let screen = screen(with: record.displayID) else {
            cleanupGeneratedArtwork(keeping: nil)
            return
        }

        do {
            try workspace.setDesktopImageURL(originalURL, for: screen, options: [:])
            try? fileManager.removeItem(at: recoveryURL)
            cleanupGeneratedArtwork(keeping: nil)
        } catch {
            print("[LockScreenWallpaper] Recovery failed: \(error)")
        }
    }

    func apply(
        artwork: NSImage,
        on screen: NSScreen,
        onReadyToApply: @escaping @MainActor () -> Void = {}
    ) {
        cleanupTask?.cancel()
        cleanupTask = nil
        operationID = UUID()
        let currentOperationID = operationID

        guard let sourceImage = artwork.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ),
              let originalURL = originalWallpaper?.url ?? workspace.desktopImageURL(for: screen) else {
            onReadyToApply()
            return
        }

        do {
            try fileManager.createDirectory(
                at: workingDirectoryURL,
                withIntermediateDirectories: true
            )

            if originalWallpaper == nil {
                let original = OriginalWallpaper(
                    url: originalURL,
                    options: workspace.desktopImageOptions(for: screen) ?? [:],
                    displayID: displayID(for: screen)
                )
                originalWallpaper = original
                try persistRecovery(for: original)
            }

            let artworkURL = workingDirectoryURL
                .appendingPathComponent("artwork-\(UUID().uuidString).jpg")
            let backingScale = max(screen.backingScaleFactor, 1)
            let targetSize = CGSize(
                width: screen.frame.width * backingScale,
                height: screen.frame.height * backingScale
            )
            let targetDisplayID = displayID(for: screen)
            let renderer = renderer

            renderQueue.async { [weak self] in
                guard let jpegData = renderer.renderJPEG(
                    sourceImage: sourceImage,
                    targetSize: targetSize
                ) else {
                    DispatchQueue.main.async {
                        self?.cancelFailedApply(operationID: currentOperationID)
                        onReadyToApply()
                    }
                    return
                }

                do {
                    try jpegData.write(to: artworkURL, options: .atomic)
                } catch {
                    DispatchQueue.main.async {
                        self?.cancelFailedApply(operationID: currentOperationID)
                        onReadyToApply()
                    }
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self, self.operationID == currentOperationID else {
                        try? FileManager.default.removeItem(at: artworkURL)
                        return
                    }
                    guard let targetScreen = self.screen(with: targetDisplayID) else {
                        self.cancelFailedApply(operationID: currentOperationID)
                        onReadyToApply()
                        return
                    }

                    var options = self.workspace.desktopImageOptions(for: targetScreen) ?? [:]
                    options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
                    options[.allowClipping] = true

                    onReadyToApply()
                    do {
                        // A single system wallpaper update avoids frame drops in SwiftUI.
                        try self.workspace.setDesktopImageURL(
                            artworkURL,
                            for: targetScreen,
                            options: options
                        )
                        self.activeArtworkURL = artworkURL
                        self.cleanupGeneratedArtwork(keeping: artworkURL)
                    } catch {
                        print("[LockScreenWallpaper] Apply failed: \(error)")
                        self.cancelFailedApply(operationID: currentOperationID)
                    }
                }
            }
        } catch {
            print("[LockScreenWallpaper] Prepare failed: \(error)")
            cancelFailedApply(operationID: currentOperationID)
            onReadyToApply()
        }
    }

    func restore() {
        restoreOriginalWallpaper()
    }

    func restoreAnimated() {
        restoreOriginalWallpaper()
    }

    func restoreSynchronously() {
        restoreOriginalWallpaper()
    }

    private func restoreOriginalWallpaper() {
        operationID = UUID()
        guard let originalWallpaper,
              let targetScreen = screen(with: originalWallpaper.displayID) else { return }

        do {
            try workspace.setDesktopImageURL(
                originalWallpaper.url,
                for: targetScreen,
                options: originalWallpaper.options
            )
            self.originalWallpaper = nil
            activeArtworkURL = nil
            try? fileManager.removeItem(at: recoveryURL)
            scheduleGeneratedArtworkCleanup()
        } catch {
            print("[LockScreenWallpaper] Restore failed: \(error)")
        }
    }

    private func cancelFailedApply(operationID failedOperationID: UUID) {
        guard operationID == failedOperationID else { return }
        guard activeArtworkURL == nil else { return }
        originalWallpaper = nil
        try? fileManager.removeItem(at: recoveryURL)
        scheduleGeneratedArtworkCleanup()
    }

    private func persistRecovery(for wallpaper: OriginalWallpaper) throws {
        let record = RecoveryRecord(
            url: wallpaper.url.absoluteString,
            displayID: wallpaper.displayID
        )
        let data = try JSONEncoder().encode(record)
        try data.write(to: recoveryURL, options: .atomic)
    }

    private func scheduleGeneratedArtworkCleanup() {
        cleanupTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.cleanupGeneratedArtwork(keeping: nil)
            self?.cleanupTask = nil
        }
        cleanupTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task)
    }

    private func cleanupGeneratedArtwork(keeping activeURL: URL?) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: workingDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for fileURL in files where
            fileURL.lastPathComponent.hasPrefix("artwork-")
                || fileURL.lastPathComponent.hasPrefix("transition-") {
            guard fileURL != activeURL else { continue }
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber).map {
            CGDirectDisplayID($0.uint32Value)
        }
    }

    private func screen(with displayID: UInt32?) -> NSScreen? {
        guard let displayID else { return NSScreen.main ?? NSScreen.screens.first }
        return NSScreen.screens.first { self.displayID(for: $0) == displayID }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

private nonisolated final class LockScreenBackdropRenderer: @unchecked Sendable {
    private static let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    private let maximumSide: CGFloat
    private let context = CIContext(options: [
        .cacheIntermediates: false,
        .workingColorSpace: outputColorSpace,
        .outputColorSpace: outputColorSpace
    ])

    init(maximumSide: CGFloat) {
        self.maximumSide = maximumSide
    }

    func renderJPEG(sourceImage: CGImage, targetSize: CGSize) -> Data? {
        let composition = LockScreenBackdropComposition(
            sourceImage: sourceImage,
            targetSize: targetSize,
            maximumSide: maximumSide
        )
        guard let outputImage = context.createCGImage(
            composition.image,
            from: composition.extent,
            format: .RGBA8,
            colorSpace: Self.outputColorSpace
        ),
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                destinationData,
                "public.jpeg" as CFString,
                1,
                nil
              ) else {
            return nil
        }

        let properties = [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
        CGImageDestinationAddImage(destination, outputImage, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }
}

private nonisolated struct LockScreenBackdropComposition {
    let image: CIImage
    let extent: CGRect

    init(sourceImage: CGImage, targetSize: CGSize, maximumSide: CGFloat) {
        let targetWidth = max(1, targetSize.width)
        let targetHeight = max(1, targetSize.height)
        let renderScale = min(1, maximumSide / max(targetWidth, targetHeight))
        let renderWidth = max(1, floor(targetWidth * renderScale))
        let renderHeight = max(1, floor(targetHeight * renderScale))
        let extent = CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight)
        let inputImage = CIImage(cgImage: sourceImage)
        let fillScale = max(
            renderWidth / inputImage.extent.width,
            renderHeight / inputImage.extent.height
        )
        let scaledImage = inputImage.transformed(
            by: CGAffineTransform(scaleX: fillScale, y: fillScale)
        )
        let centeredImage = scaledImage.transformed(
            by: CGAffineTransform(
                translationX: (renderWidth - scaledImage.extent.width) / 2 - scaledImage.extent.minX,
                y: (renderHeight - scaledImage.extent.height) / 2 - scaledImage.extent.minY
            )
        )
        let blurRadius = max(38, min(renderWidth, renderHeight) * 0.055)
        let backdrop = centeredImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: extent)
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0.96,
                    kCIInputBrightnessKey: -0.05,
                    kCIInputContrastKey: 0.98
                ]
            )
            .applyingFilter("CIVibrance", parameters: ["inputAmount": -0.10])
        let dimmingLayer = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.18))
            .cropped(to: extent)

        self.image = dimmingLayer.composited(over: backdrop)
        self.extent = extent
    }
}
