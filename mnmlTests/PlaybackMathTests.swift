//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct PlaybackMathTests {
    @Test func skipBackClampsAtZero() {
        #expect(PlaybackMath.skipBack(from: 10, total: 100) == 0)  // 10-30 → 0
        #expect(PlaybackMath.skipBack(from: 50, total: 100) == 20)
    }

    @Test func skipForwardClampsAtTotal() {
        #expect(PlaybackMath.skipForward(from: 90, total: 100) == 100)  // 90+30 → 100
        #expect(PlaybackMath.skipForward(from: 50, total: 100) == 80)
    }

    @Test func speedCycles() {
        #expect(PlaybackMath.nextSpeed(after: 1.0) == 1.25)
        #expect(PlaybackMath.nextSpeed(after: 2.0) == 0.5)  // wraps past the max to the 0.5 minimum
        #expect(PlaybackMath.nextSpeed(after: 0.8) == 1.0)
    }

    @Test func speedLabelTrimsTrailingZeros() {
        #expect(PlaybackMath.speedLabel(1.0) == "1×")
        #expect(PlaybackMath.speedLabel(1.25) == "1.25×")
        #expect(PlaybackMath.speedLabel(0.8) == "0.8×")
    }

    @Test func listenedDeltaCountsOnlySmallForwardSteps() {
        #expect(PlaybackMath.listenedDelta(from: 10, to: 10.5) == 0.5)  // normal tick
        #expect(PlaybackMath.listenedDelta(from: 10, to: 10) == 0)  // paused / no movement
        #expect(PlaybackMath.listenedDelta(from: 40, to: 10) == 0)  // seek back
        #expect(PlaybackMath.listenedDelta(from: 10, to: 40) == 0)  // seek forward / chapter jump
        #expect(PlaybackMath.listenedDelta(from: 10, to: 15) == 5)  // boundary: still counts
    }

    @Test func smartRewindScalesWithPauseDuration() {
        // Below the floor: a momentary pause loses nothing.
        #expect(PlaybackMath.smartRewind(pausedFor: 0) == 0)
        #expect(PlaybackMath.smartRewind(pausedFor: -5) == 0)  // defensive: negative elapsed
        #expect(PlaybackMath.smartRewind(pausedFor: 9) == 0)
        // < 1 minute → 2s
        #expect(PlaybackMath.smartRewind(pausedFor: 10) == 2)  // boundary
        #expect(PlaybackMath.smartRewind(pausedFor: 59) == 2)
        // < 1 hour → 5s
        #expect(PlaybackMath.smartRewind(pausedFor: 60) == 5)  // boundary
        #expect(PlaybackMath.smartRewind(pausedFor: 3599) == 5)
        // < 1 day → 10s
        #expect(PlaybackMath.smartRewind(pausedFor: 3600) == 10)  // boundary
        #expect(PlaybackMath.smartRewind(pausedFor: 86399) == 10)
        // >= 1 day → 20s
        #expect(PlaybackMath.smartRewind(pausedFor: 86400) == 20)  // boundary
        #expect(PlaybackMath.smartRewind(pausedFor: 5_000_000) == 20)
    }
}
