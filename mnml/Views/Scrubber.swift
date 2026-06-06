//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// 3px track, accent fill, draggable 11px accent thumb. Tap or drag to seek.
struct Scrubber: View {
    let fraction: Double  // 0...1
    let onSeek: (Double) -> Void  // new fraction
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track(scheme)).frame(height: 3)
                Capsule().fill(Theme.accent).frame(width: w * clamped, height: 3)
                Circle().fill(Theme.accent).frame(width: 11, height: 11)
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                    .offset(x: w * clamped - 5.5)
            }
            .frame(height: 44)  // ≥44 tap target
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        onSeek(min(1, max(0, v.location.x / w)))
                    }
            )
        }
        .frame(height: 44)
    }

    private var clamped: Double { min(1, max(0, fraction)) }
}
