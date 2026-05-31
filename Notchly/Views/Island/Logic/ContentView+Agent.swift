//
//  ContentView+Agent.swift
//  Notchly
//
//  Created by user on 29.05.2026.
//

import SwiftUI

extension ContentView {
    var agentContainer: some View {
        let event = activeAgentEvent

        return IslandContainerView(
            size: layout.musicPreviewSize,
            cornerRadius: 24,
            spacing: layout.spacing,
            showsTopCornerCutouts: false
        ) {
            AgentActivityView(
                event: event,
                size: layout.musicPreviewSize
            )
            .offset(y: 10)
            .transition(.opacity)
        }
        .overlay {
            IslandClickCatcher {
                openAgentSourceApp(event)
            }
        }
    }
}
