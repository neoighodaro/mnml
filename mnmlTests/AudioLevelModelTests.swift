//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

struct AudioLevelModelTests {
    // MARK: curve

    @Test func curveMapsEndpoints() {
        #expect(AudioLevelModel.curve(0) == 0)
        #expect(abs(AudioLevelModel.curve(1) - 1) < 0.0001)
    }

    @Test func curveClampsOutOfRange() {
        #expect(AudioLevelModel.curve(-0.5) == 0)
        #expect(AudioLevelModel.curve(2) == 1)
    }

    @Test func curveIsMonotonicAndLiftsLowEnd() {
        // Monotonic increasing.
        #expect(AudioLevelModel.curve(0.1) < AudioLevelModel.curve(0.2))
        #expect(AudioLevelModel.curve(0.2) < AudioLevelModel.curve(0.8))
        // Low RMS (speech clusters low) is lifted above the linear value so motion is visible.
        #expect(AudioLevelModel.curve(0.1) > 0.1)
    }

    // MARK: smoothing (EMA, fast attack / slow release)

    @Test func updateRisesTowardLoudTarget() {
        var model = AudioLevelModel()
        let first = model.update(rms: 1, dt: 0.016)
        #expect(first > 0)  // moved off the floor
        #expect(first < 1)  // but not instantly pinned
    }

    @Test func attackIsFasterThanRelease() {
        // From silence, one frame toward loud rises by more than one frame
        // back toward silence falls, for the same dt.
        var rising = AudioLevelModel()
        let up = rising.update(rms: 1, dt: 0.016)

        var falling = AudioLevelModel()
        _ = falling.update(rms: 1, dt: 1.0)  // settle near the top
        let beforeDrop = falling.update(rms: 1, dt: 1.0)
        let afterDrop = falling.update(rms: 0, dt: 0.016)
        let down = beforeDrop - afterDrop

        #expect(up > down)
    }

    @Test func updateStaysInUnitRange() {
        var model = AudioLevelModel()
        for _ in 0..<200 { _ = model.update(rms: 5, dt: 0.016) }  // out-of-range input
        let v = model.update(rms: 5, dt: 0.016)
        #expect(v >= 0 && v <= 1)
    }

    @Test func decaysTowardZeroWhenSilent() {
        var model = AudioLevelModel()
        _ = model.update(rms: 1, dt: 1.0)
        let high = model.update(rms: 1, dt: 1.0)
        _ = model.update(rms: 0, dt: 1.0)
        let low = model.update(rms: 0, dt: 1.0)
        #expect(low < high)
        #expect(low < 0.1)
    }

    @Test func resetSnapsToZeroImmediately() {
        // After settling near the top, reset must drop the smoothed value straight to
        // rest — no slow release. This is the pause path: the level empties at once.
        var model = AudioLevelModel()
        _ = model.update(rms: 1, dt: 1.0)
        #expect(model.smoothed > 0.5)  // genuinely filled first
        model.reset()
        #expect(model.smoothed == 0)
    }
}
