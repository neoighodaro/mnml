//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Testing

@testable import mnml

struct RecentGradientTests {
    @Test func knownTintMapsToItsInkAsTop() {
        // clay ink is 0x5A4836 (see CoverTint.pairs).
        #expect(RecentGradient.topHex(for: "clay") == 0x5A4836)
    }

    @Test func bottomIsDarkerThanTop() {
        let top = RecentGradient.topHex(for: "slate")
        let bottom = RecentGradient.bottomHex(for: "slate")
        // Compare summed channels — bottom should be no brighter than top.
        func luma(_ h: UInt32) -> UInt32 { ((h >> 16) & 0xFF) + ((h >> 8) & 0xFF) + (h & 0xFF) }
        #expect(luma(bottom) <= luma(top))
    }

    @Test func unknownTintFallsBackToSlate() {
        #expect(RecentGradient.topHex(for: "bogus") == RecentGradient.topHex(for: "slate"))
    }

    @Test func lightTopMapsToTintBackground() {
        // clay bg is 0xE4D8CD (see CoverTint.pairs).
        #expect(RecentGradient.lightTopHex(for: "clay") == 0xE4D8CD)
    }

    @Test func lightBottomIsDarkerThanLightTop() {
        let top = RecentGradient.lightTopHex(for: "slate")
        let bottom = RecentGradient.lightBottomHex(for: "slate")
        func luma(_ h: UInt32) -> UInt32 { ((h >> 16) & 0xFF) + ((h >> 8) & 0xFF) + (h & 0xFF) }
        #expect(luma(bottom) <= luma(top))
    }

    @Test func lightTopIsLighterThanDarkTop() {
        // Light mode uses the pastel bg, which must be brighter than the dark ink.
        func luma(_ h: UInt32) -> UInt32 { ((h >> 16) & 0xFF) + ((h >> 8) & 0xFF) + (h & 0xFF) }
        for tint in ["clay", "sage", "slate", "sand", "plum", "mist"] {
            #expect(
                luma(RecentGradient.lightTopHex(for: tint)) > luma(RecentGradient.topHex(for: tint))
            )
        }
    }

    @Test func unknownTintLightFallsBackToSlate() {
        #expect(
            RecentGradient.lightTopHex(for: "bogus") == RecentGradient.lightTopHex(for: "slate"))
    }
}
