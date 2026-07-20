//
//  NetworkStatusView.swift
//  Notchly
//
//  Created by n0xbyte on 20.07.2026.
//


import SwiftUI

struct NetworkStatusView: View {
    let event: NetworkStatusEvent?
    let size: CGSize
    let isExpanded: Bool

    @State private var presentationID = 0

    private var content: NetworkStatusContent {
        NetworkStatusContent(event: event)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: content.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(content.color)
                    .frame(width: 22, height: 22)
                    .symbolEffect(.bounce, value: presentationID)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isExpanded {
                HStack(spacing: 6) {
                    Image(systemName: content.statusSymbolName)
                        .font(.system(size: 11, weight: .semibold))

                    Text(content.statusText)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
        }
        .padding(.horizontal, 12)
        .frame(width: size.width, height: size.height, alignment: .top)
        .overlay(alignment: .topTrailing) {
            if !isExpanded {
                Image(systemName: content.statusSymbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(content.color.opacity(0.82))
                    .frame(width: 22, height: 22)
                    .padding(.trailing, 12)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            presentationID += 1
        }
        .onChange(of: event) { _, _ in
            presentationID += 1
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

private struct NetworkStatusContent {
    let symbolName: String
    let statusSymbolName: String
    let statusText: String
    let accessibilityLabel: String
    let color: Color

    init(event: NetworkStatusEvent?) {
        guard let event else {
            symbolName = "wifi"
            statusSymbolName = "ellipsis"
            statusText = "Checking Wi-Fi"
            accessibilityLabel = "Checking Wi-Fi status"
            color = .white
            return
        }

        let networkName = event.networkName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let wifiTitle = networkName.flatMap { $0.isEmpty ? nil : $0 } ?? "Wi-Fi"

        switch event.kind {
        case .wifiConnected:
            symbolName = "wifi"
            statusSymbolName = "checkmark.circle.fill"
            statusText = "Connected to \(wifiTitle)"
            accessibilityLabel = "\(wifiTitle), connected"
            color = Color(red: 0.42, green: 0.83, blue: 1.0)
        case .personalHotspot:
            symbolName = "personalhotspot"
            statusSymbolName = "checkmark.circle.fill"
            statusText = "Personal Hotspot Connected"
            accessibilityLabel = "Personal Hotspot, connected"
            color = Color(red: 0.42, green: 0.83, blue: 1.0)
        case .internetRestored:
            symbolName = "wifi"
            statusSymbolName = "checkmark.circle.fill"
            statusText = "Internet Restored"
            accessibilityLabel = "\(wifiTitle), internet restored"
            color = Color(red: 0.42, green: 0.92, blue: 0.58)
        case .noInternet:
            symbolName = "wifi"
            statusSymbolName = "exclamationmark.triangle.fill"
            statusText = "No Internet Connection"
            accessibilityLabel = "\(wifiTitle), no internet"
            color = Color(red: 1.0, green: 0.68, blue: 0.28)
        case .disconnected:
            symbolName = "wifi.slash"
            statusSymbolName = "xmark.circle.fill"
            statusText = "Wi-Fi Disconnected"
            accessibilityLabel = "Wi-Fi disconnected"
            color = Color(red: 1.0, green: 0.48, blue: 0.42)
        case .wifiOff:
            symbolName = "wifi.slash"
            statusSymbolName = "power"
            statusText = "Wi-Fi Turned Off"
            accessibilityLabel = "Wi-Fi off"
            color = Color(red: 1.0, green: 0.48, blue: 0.42)
        }
    }
}
