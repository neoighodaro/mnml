//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct BookMathTests {
    let durations: [Double] = [8520, 13800, 9600, 5760]

    @Test func totalDurationSumsChapters() {
        #expect(BookMath.totalDuration(durations) == 37680)
    }

    @Test func locateFindsChapterAndOffset() {
        let loc = BookMath.locate(progress: 9240, durations: durations)
        #expect(loc.index == 1)
        #expect(loc.base == 8520)
        #expect(loc.into == 720)
    }

    @Test func locateAtStartIsChapterZero() {
        let loc = BookMath.locate(progress: 0, durations: durations)
        #expect(loc.index == 0)
        #expect(loc.base == 0)
    }

    @Test func locatePastEndClampsToLastChapter() {
        let loc = BookMath.locate(progress: 999999, durations: durations)
        #expect(loc.index == 3)
        #expect(loc.base == 8520 + 13800 + 9600)
    }

    @Test func chapterBaseAccumulates() {
        #expect(BookMath.chapterBase(index: 2, durations: durations) == 8520 + 13800)
        #expect(BookMath.chapterBase(index: 0, durations: durations) == 0)
    }

    // MARK: - Boundary / edge-case contract

    /// Exact boundary (8520 == end of ch 0) must belong to ch 1, not ch 0.
    @Test func locateOnExactBoundaryBelongsToNextChapter() {
        let loc = BookMath.locate(progress: 8520, durations: durations)
        #expect(loc.index == 1)
        #expect(loc.base == 8520)
        #expect(loc.into == 0)
    }

    /// Progress equal to the total duration clamps to the last chapter with into = lastDuration.
    @Test func locateAtExactTotalEndClampsToLast() {
        let loc = BookMath.locate(progress: 37680, durations: durations)
        #expect(loc.index == 3)
        #expect(loc.base == 31920)
        #expect(loc.into == 5760)
    }

    /// Empty durations array returns the zero Location without crashing.
    @Test func locateWithEmptyDurationsReturnsZeroLocation() {
        let loc = BookMath.locate(progress: 0, durations: [])
        #expect(loc.index == 0)
        #expect(loc.into == 0)
        #expect(loc.base == 0)
    }
}
