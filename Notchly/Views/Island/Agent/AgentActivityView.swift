//
//  AgentActivityView.swift
//  Notchly
//
//  Created by n0xbyte on 29.05.2026.
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
        event?.title ?? "Task completed"
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch event?.source.lowercased() {
        case "codex":
            Image("CodexAgentIcon")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 22, height: 22)
        case "cursor":
            Image("CursorAgentIcon")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 22, height: 22)
        default:
            Image(systemName: sourceIconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(sourceIconColor)
                .frame(width: 22, height: 22)
        }
    }

    private var sourceIconName: String {
        guard let source = event?.source.lowercased() else { return "sparkles" }

        switch source {
        case "codex":
            return "terminal.fill"
        case "cursor":
            return "cursorarrow"
        default:
            return "sparkles"
        }
    }

    private var sourceIconColor: Color {
        switch event?.source.lowercased() {
        case "codex":
            return Color(red: 0.50, green: 0.80, blue: 1.0)
        case "cursor":
            return Color(red: 0.62, green: 0.72, blue: 1.0)
        default:
            return .white.opacity(0.78)
        }
    }

}
