//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

struct LevelFillEffectTests {
    // A fixed square keeps the arithmetic obvious: fractions of height map to round numbers.
    private let size = CGSize(width: 100, height: 100)

    private func tol(_ a: CGFloat, _ b: CGFloat) -> Bool {
        abs(a - b) < 0.0001
    }

    @Test func emptyFillIsZeroHeightAtBottom() {
        // No fill: the waterline sits at the bottom, so the rect has no height.
        let rect = LevelFillEffect.fillRect(in: size, fill: 0).boundingRect
        #expect(tol(rect.origin.y, size.height))
        #expect(tol(rect.size.height, 0))
    }

    @Test func fullFillSpansWholeHeight() {
        // Full fill: waterline at the top, rect covers the entire height.
        let rect = LevelFillEffect.fillRect(in: size, fill: 1).boundingRect
        #expect(tol(rect.origin.y, 0))
        #expect(tol(rect.size.height, size.height))
    }

    @Test func halfFillSitsAtMidHeight() {
        // Half fill: waterline at mid-height, lower half submerged.
        let rect = LevelFillEffect.fillRect(in: size, fill: 0.5).boundingRect
        #expect(tol(rect.origin.y, 50))
        #expect(tol(rect.size.height, 50))
    }

    @Test func clampsAboveOneToFull() {
        // Over-range loudness must not overflow the tank — clamps to full.
        let rect = LevelFillEffect.fillRect(in: size, fill: 2).boundingRect
        #expect(tol(rect.origin.y, 0))
        #expect(tol(rect.size.height, size.height))
    }

    @Test func clampsBelowZeroToEmpty() {
        // Negative loudness must not produce an inverted rect — clamps to empty.
        let rect = LevelFillEffect.fillRect(in: size, fill: -1).boundingRect
        #expect(tol(rect.origin.y, size.height))
        #expect(tol(rect.size.height, 0))
    }
}
