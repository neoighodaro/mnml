//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// The audio-reactive level fill for the play/pause glyph. A `TimelineView(.animation)`
/// redraws a `Canvas` each frame: it reads the engine's current RMS via `level()`,
/// smooths it through `AudioLevelModel`, and fills a bottom-anchored rectangle whose
/// flat top edge (the waterline) tracks loudness. Masked to the glyph shape at the call
/// site so the level rises *inside* the icon. Purely decorative — set
/// `.allowsHitTesting(false)` so taps reach the button.
///
/// Kept **always mounted** at the call site (not gated behind `if isPlaying`): pausing is
/// expressed by the `isPlaying` flag, not by removing the view. That matters because an
/// unmount animates a *snapshot* of the last filled frame fading out — the level appears to
/// linger. Mounted-always, the Canvas simply redraws empty the next frame, so the fill drops
/// to zero immediately on pause with no fade.
struct LevelFillEffect: View {
    /// Latest audio loudness (≈0…1). A closure so the view stays decoupled from the engine.
    let level: () -> Float

    /// Whether playback is active. The drain-to-zero and start-delay re-arm key off this
    /// (not off a zero RMS sample) so a momentary silence mid-playback isn't mistaken for a
    /// pause: only a real pause empties the tank and re-arms the delay.
    var isPlaying: Bool

    /// The submerged region's color. Above the waterline stays clear, so the white glyph
    /// shows through there.
    var color: Color = Theme.accent

    @State private var holder = Holder()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Loudest passages fill to this fraction of height; a sliver of blue stays at the top.
    private let maxFill: Float = 0.92
    /// Amplifies the smoothed energy before it drives the waterline, so the level reacts
    /// more aggressively — mid passages sit higher and loud ones pin to the top sooner.
    private let gain: Float = 1.35
    /// On each play the level ramps from empty to full over this many seconds so it eases in
    /// rather than popping on at whatever the current loudness happens to be.
    private let fadeIn: Double = 0.3

    final class Holder {
        var model = AudioLevelModel()
        var lastTime: Double?
        /// Reference time of the first rendered frame after playback (re)started — the start of
        /// the fade-in ramp. Nil while paused, so the next play re-arms it.
        var startTime: Double?
    }

    var body: some View {
        if reduceMotion {
            Color.clear  // Reduce Motion: no reactive fill — just the plain blue button.
        } else {
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let dt = Float(holder.lastTime.map { now - $0 } ?? 0.016)
                    holder.lastTime = now

                    guard isPlaying else {
                        // Paused/stopped: empty the tank at once (the Canvas redraws zero this
                        // frame — no lingering fade) and re-arm the fade-in for next play.
                        holder.model.reset()
                        holder.startTime = nil
                        return
                    }

                    if holder.startTime == nil { holder.startTime = now }
                    let elapsed = now - (holder.startTime ?? now)
                    // The level shows from the start of playback, easing in over fadeIn so it
                    // doesn't pop on at the current loudness.
                    let energy = holder.model.update(rms: level(), dt: dt)
                    let gate = Float(min(max(elapsed / fadeIn, 0), 1))
                    let fill = min(energy * gain, 1) * maxFill * gate
                    ctx.fill(
                        Self.fillRect(in: size, fill: fill),
                        with: .color(color))
                }
            }
        }
    }

    /// The submerged region: a bottom-anchored rectangle whose flat top edge (the
    /// waterline) sits at `fill` (0…1) of the height from the bottom. Clamps to 0…1.
    static func fillRect(in size: CGSize, fill: Float) -> Path {
        let clamped = CGFloat(min(max(fill, 0), 1))
        let surfaceY = size.height * (1 - clamped)
        return Path(
            CGRect(
                x: 0, y: surfaceY,
                width: size.width, height: size.height - surfaceY))
    }
}
