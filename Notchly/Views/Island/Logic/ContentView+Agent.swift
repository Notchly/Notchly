//
//  ContentView+Agent.swift
//  Notchly
//
//  Created by user on 29.05.2026.
//

import SwiftUI

extension ContentView {
    var agentContainer: some View {
        IslandContainerView(
            size: layout.musicPreviewSize,
            cornerRadius: 24,
            spacing: layout.spacing
        ) {
            AgentActivityView(
                event: agentEventManager.currentEvent,
                size: layout.musicPreviewSize
            )
            .offset(y: 10)
            .transition(.opacity)
        }
        .overlay {
            IslandClickCatcher {
                openAgentSourceApp(agentEventManager.currentEvent)
            }
        }
    }
}
