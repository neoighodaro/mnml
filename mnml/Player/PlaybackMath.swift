//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Pure transport math from the handoff: skip back/forward 30s, speed cycle.
enum PlaybackMath {
    static let speeds: [Double] = [0.5, 0.8, 1, 1.25, 1.5, 1.75, 2]

    static func skipBack(from t: Double, total: Double) -> Double {
        max(0, t - 30)
    }
    static func skipForward(from t: Double, total: Double) -> Double {
        min(total, t + 30)
    }
    static func nextSpeed(after s: Double) -> Double {
        let i = speeds.firstIndex(of: s) ?? 1
        return speeds[(i + 1) % speeds.count]
    }
    static func speedLabel(_ s: Double) -> String {
        let str = s == s.rounded() ? String(Int(s)) : String(s)
        return "\(str)×"
    }

    /// Largest per-tick forward jump still counted as listening. The time observer fires
    /// every 0.25s; even at the 2× max speed the real advance is ~0.5s, so anything beyond
    /// a few seconds is a seek/chapter jump, not listening.
    static let maxListenStep: Double = 5

    /// Content-seconds to credit between two playback-position samples. Only small forward
    /// steps count; large or negative jumps (seeks, chapter skips) credit 0.
    static func listenedDelta(from previous: Double, to current: Double) -> Double {
        let delta = current - previous
        return (delta > 0 && delta <= maxListenStep) ? delta : 0
    }

    /// Seconds to rewind on resume, scaled by how long playback was paused. A
    /// momentary pause loses nothing; a long absence rewinds enough to re-orient.
    /// Thresholds: <10s → 0, <1min → 2, <1hr → 5, <1day → 10, else 20.
    static func smartRewind(pausedFor seconds: Double) -> Double {
        switch seconds {
        case ..<10: return 0
        case ..<60: return 2
        case ..<3600: return 5
        case ..<86400: return 10
        default: return 20
        }
    }
}
