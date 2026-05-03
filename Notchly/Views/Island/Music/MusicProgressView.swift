//
//  MusicProgressView.swift
//  Notchly
//
//  Created by user on 25.03.2026.
//

import SwiftUI

struct MusicProgressView: View {
    let progress: CGFloat
    let waveformColor: Color
    let onPreviewSeek: (CGFloat) -> Void
    let onSeek: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                waveformColor.opacity(0.95),
                                Color.white.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, geo.size.width * progress))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = min(max(value.location.x / geo.size.width, 0), 1)
                        onPreviewSeek(progress)
                    }
                    .onEnded { value in
                        let progress = min(max(value.location.x / geo.size.width, 0), 1)
                        onSeek(progress)
                    }
            )
        }
        .frame(height: 8)
    }
}
