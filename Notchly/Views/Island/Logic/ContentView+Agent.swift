//
//  ContentView+Agent.swift
//  Notchly
//
//  Created by n0xbyte on 29.05.2026.
//

import SwiftUI

extension ContentView {
    @ViewBuilder
    var agentContainer: some View {
        let event = activeAgentEvent
        let containerSize: CGSize = {
            switch status {
            case .closed:
                return canUseCompactAgentClosedSize ? idleNotchSize : layout.closedSize
            case .agentCollapse:
                return layout.agentCollapsedSize
            case .agentPreview:
                return layout.agentPreviewSize
            default:
                return layout.agentPreviewSize
            }
        }()

        if event == nil {
            emptyBar
        } else if status == .closed && !isStandaloneAgentClosing {
            EmptyIslandView(
                size: containerSize,
                cornerRadius: layout.cornerRadius,
                spacing: layout.spacing,
                isHovered: isHovered
            )
            .animation(.smooth(duration: 0.42, extraBounce: 0), value: containerSize.width)
            .animation(.smooth(duration: 0.42, extraBounce: 0), value: containerSize.height)
            .animation(.smooth(duration: 0.42, extraBounce: 0), value: layout.cornerRadius)
        } else {
            AgentIslandFrame(
                size: containerSize,
                cornerRadius: layout.cornerRadius,
                spacing: layout.spacing,
                isHovered: isHovered
            ) {
                ZStack(alignment: .top) {
                    if showsStandaloneAgentContent && (status == .agentPreview || isStandaloneAgentClosing) {
                        AgentActivityView(
                            event: event,
                            size: layout.agentPreviewSize
                        )
                        .id(agentPresentationContentKey(for: event))
                        .offset(y: 10)
                        .transition(
                            .asymmetric(
                                insertion: .agentContentSlide(y: -14),
                                removal: .identity
                            )
                        )
                    }
                }
                .frame(width: layout.agentPreviewSize.width + layout.cornerRadius * 2, height: layout.agentPreviewSize.height)
            }
            .overlay {
                IslandClickCatcher {
                    openAgentSourceApp(event)
                }
            }
            .animation(animation, value: containerSize.width)
            .animation(animation, value: containerSize.height)
            .animation(animation, value: layout.cornerRadius)
        }
    }
}

struct AgentIslandFrame<Content: View>: View {
    let size: CGSize
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let isHovered: Bool
    let content: Content

    init(
        size: CGSize,
        cornerRadius: CGFloat,
        spacing: CGFloat,
        isHovered: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.isHovered = isHovered
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .foregroundStyle(.black)

            content
        }
        .frame(
            width: size.width + cornerRadius * 2,
            height: size.height,
            alignment: .top
        )
        .clipped()
        .mask(
            IslandMaskView(
                size: size,
                cornerRadius: cornerRadius,
                spacing: spacing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.white.opacity(isHovered ? 0.09 : 0.04), lineWidth: 1)
                .frame(width: size.width, height: size.height)
        }
        .shadow(color: .black.opacity(0.12), radius: 12)
    }
}

private struct AgentContentSlideModifier: ViewModifier {
    let y: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: y)
    }
}

private extension AnyTransition {
    static func agentContentSlide(y: CGFloat) -> AnyTransition {
        .modifier(
            active: AgentContentSlideModifier(y: y),
            identity: AgentContentSlideModifier(y: 0)
        )
    }
}
