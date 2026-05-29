//
//  AgentActivityView.swift
//  Notchly
//
//  Created by user on 29.05.2026.
//

import SwiftUI

struct AgentActivityView: View {
    let event: AgentEvent?
    let size: CGSize

    var body: some View {
        Group {
            if event != nil {
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        sourceIcon
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))

                        Text(secondaryText)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 12)
                .frame(width: size.width, height: size.height, alignment: .top)
            }
        }
        .allowsHitTesting(false)
    }

    private var secondaryText: String {
        event?.title ?? "Response generated"
    }

    private var showsTrailingWaveform: Bool {
        guard let event else { return false }
        return !(event.source.lowercased() == "chatgpt" && event.kind == .completed)
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if event?.source.lowercased() == "chatgpt" {
            Image("ChatGPTAgentIcon")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 22, height: 22)
        } else if event?.source.lowercased() == "codex" {
            Image("CodexAgentIcon")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: sourceIconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sourceIconColor)
                .frame(width: 22, height: 22)
        }
    }

    private var sourceIconName: String {
        guard let source = event?.source.lowercased() else { return "sparkles" }

        switch source {
        case "chatgpt":
            return "bubble.left.and.text.bubble.right.fill"
        case "codex":
            return "terminal.fill"
        default:
            return "sparkles"
        }
    }

    private var sourceIconColor: Color {
        switch event?.source.lowercased() {
        case "chatgpt":
            return Color(red: 0.40, green: 0.88, blue: 0.68)
        case "codex":
            return Color(red: 0.50, green: 0.80, blue: 1.0)
        default:
            return .white.opacity(0.78)
        }
    }

}
