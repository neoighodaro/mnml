//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// iCloud transfer indicator for a book. Renders nothing once the file is fully
/// synced (`.synced`), so it only ever appears when there's something to show:
///   - uploading   — accent ↑ glyph, the file is going up to iCloud
///   - downloading — accent ↓ glyph, the file is being pulled back to this device
///   - cloudOnly   — white cloud glyph: the book lives in iCloud but isn't on this
///                   device (tap Play to download it)
///
/// All states render as a bare filled SF Symbol — no circle backing. Color carries
/// the meaning: accent = something's transferring, white = it's just sitting in the
/// cloud. The active-transfer states share one arrow glyph each; cloud-only uses the
/// plain `icloud.fill` so it never collides with the download arrow. A soft shadow
/// keeps the glyph legible over any cover art.
///
/// Two looks: just the glyph on book covers, and a labeled variant for the detail
/// header that shows the transfer percentage when the system reports one.
struct CloudStateBadge: View {
    let state: BookCloudState
    /// Detail screens show the percentage beside the glyph; covers show just the glyph.
    var showsPercent = false

    var body: some View {
        switch state {
        case .synced:
            EmptyView()
        case .uploading(let fraction):
            transfer(symbol: "icloud.and.arrow.up.fill", fraction: fraction, tint: Theme.accent)
        case .downloading(let fraction):
            // Over cover art the glyph stays white, like cloud-only — a downloading book
            // still reads as "in the cloud" and the arrow alone signals it's coming down.
            // The labeled header variant keeps the accent so the percent stays legible on
            // the (near-white) app background.
            transfer(
                symbol: "icloud.and.arrow.down.fill", fraction: fraction,
                tint: showsPercent ? Theme.accent : .white)
        case .cloudOnly:
            // Nothing is transferring — the file just isn't on this device. A plain
            // filled cloud (no arrow) keeps it distinct from the download state.
            glyph(symbol: "icloud.fill", tint: .white)
        case .unavailable:
            // Sync is on but the iCloud account/container isn't usable right now, so we
            // can't claim the file is uploaded. A slashed cloud reads as "not synced —
            // unavailable", distinct from cloud-only (in iCloud, just not on this device).
            glyph(symbol: "icloud.slash.fill", tint: .white)
        }
    }

    /// Active-transfer look. On the detail header (`showsPercent`) it's a labeled
    /// glyph + percentage in the tint color; on covers it's just the filled glyph.
    @ViewBuilder
    private func transfer(symbol: String, fraction: Double?, tint: Color) -> some View {
        if showsPercent {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 12))
                if let fraction {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(Typography.body(12.5, weight: .medium)).monospacedDigit()
                }
            }
            .foregroundStyle(tint)
        } else {
            glyph(symbol: symbol, tint: tint)
        }
    }

    /// Bare filled glyph used on covers — no circle. The drop shadow gives it contrast
    /// over light artwork so it stays readable without a backing shape.
    private func glyph(symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 0.5)
    }
}

extension BookCloudState {
    /// True when the badge actually draws something — so the scrim only appears when
    /// there's a glyph to give contrast to.
    var showsBadge: Bool { self != .synced }
}

extension View {
    /// A soft dark gradient hugging the top of a cover, fading to clear partway down.
    /// Gives a top-corner `CloudStateBadge` enough contrast over light artwork to stay
    /// readable, without meaningfully dimming the cover. Applied only when `state`
    /// renders a badge, and clipped to the cover's corner so it never spills past the
    /// rounded edge. Proportional stops keep it consistent across cover sizes.
    func cloudBadgeScrim(for state: BookCloudState, radius: CGFloat) -> some View {
        overlay {
            if state.showsBadge {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.28), location: 0),
                        .init(color: .clear, location: 0.45),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }
}
