//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Pure chapter math mirroring data.jsx `totalDur` / `locate` / `chBase`.
enum BookMath {
    struct Location: Equatable {
        let index: Int
        let into: Double
        let base: Double
    }

    static func totalDuration(_ durations: [Double]) -> Double {
        durations.reduce(0, +)
    }

    /// Returns the `Location` (chapter index, offset into chapter, chapter base) for a given playback
    /// position in seconds.
    ///
    /// **Boundary / edge-case contract:**
    /// - Chapter boundaries belong to the **next** chapter: a `progress` exactly equal to a chapter's
    ///   cumulative end (`acc + durations[i]`) fails the `progress < acc + durations[i]` test and
    ///   therefore maps to chapter `i + 1`, not chapter `i`.
    /// - When `progress` is at or beyond the total duration the function clamps to the last chapter,
    ///   returning `into = durations.last` (the full final-chapter duration) and
    ///   `base = totalDuration - lastDuration`.
    /// - An empty `durations` array returns `Location(index: 0, into: 0, base: 0)`; callers must
    ///   ensure a book has at least one chapter.
    static func locate(progress: Double, durations: [Double]) -> Location {
        var acc: Double = 0
        for i in durations.indices {
            if progress < acc + durations[i] {
                return Location(index: i, into: progress - acc, base: acc)
            }
            acc += durations[i]
        }
        let last = max(0, durations.count - 1)
        let base = acc - (durations.last ?? 0)
        return Location(index: last, into: durations.last ?? 0, base: base)
    }

    static func chapterBase(index: Int, durations: [Double]) -> Double {
        guard index > 0 else { return 0 }
        return durations.prefix(index).reduce(0, +)
    }
}
