//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation

/// Time helpers matching the handoff's `fmt` / `fmtLong` (data.jsx).
enum TimeFormat {
    /// seconds → "1:04:22" or "4:09"
    static func fmt(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return "\(h):\(pad(m)):\(pad(sec))" }
        return "\(m):\(pad(sec))"
    }

    /// seconds → "4h 12m" / "38m"
    static func fmtLong(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600
        let m = Int((Double(s % 3600) / 60).rounded())
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// seconds → "86h" / "38m" — compact whole-hour stat headline.
    static func fmtStat(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600
        if h > 0 { return "\(h)h" }
        let m = s / 60
        return "\(m)m"
    }

    private static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}
