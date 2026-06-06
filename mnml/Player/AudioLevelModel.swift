//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Pure, testable transform from a raw RMS audio sample to a smoothed 0…1 display
/// energy. Holds only the smoothing state; no UIKit/AVFoundation. The view owns one
/// instance and calls `update` once per frame.
struct AudioLevelModel {
    /// Smoothed output, 0…1. Starts at rest.
    private(set) var smoothed: Float = 0

    /// Maps raw RMS to a 0…1 energy. Speech RMS clusters very low, so a sub-1 power
    /// lifts the low end and spreads it across the visible range. Clamps to 0…1.
    static func curve(_ rms: Float) -> Float {
        let clamped = min(max(rms, 0), 1)
        return pow(clamped, 0.45)
    }

    /// Advances the exponential moving average toward the curved target. Fast attack
    /// (rising) makes it bounce with speech; slower release (falling) stops strobing.
    /// `dt` is the frame delta in seconds. Returns the new smoothed value (0…1).
    mutating func update(rms: Float, dt: Float) -> Float {
        let target = AudioLevelModel.curve(rms)
        let safeDt = max(dt, 0)
        // Time constants: attack ~80ms, release ~350ms.
        let tau: Float = target > smoothed ? 0.08 : 0.35
        let alpha = 1 - exp(-safeDt / tau)
        smoothed += (target - smoothed) * alpha
        smoothed = min(max(smoothed, 0), 1)
        return smoothed
    }

    /// Snaps the smoothed value straight to rest, bypassing the slow release. Used on
    /// pause so the level drops to empty immediately instead of easing down over ~350ms.
    mutating func reset() {
        smoothed = 0
    }
}
