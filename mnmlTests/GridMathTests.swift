//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import CoreGraphics
import Testing

@testable import mnml

struct GridMathTests {
    @Test func neverFewerThanTwoColumns() {
        // Narrow width that would otherwise compute to 1 column.
        #expect(GridMath.columns(forWidth: 100, targetCell: 165, gutter: 16) == 2)
    }

    @Test func iPhoneWidthGivesTwoColumns() {
        // 375pt screen minus 22pt padding each side = 331pt usable.
        #expect(GridMath.columns(forWidth: 331, targetCell: 165, gutter: 16) == 2)
    }

    @Test func iPadWidthGivesMoreColumns() {
        // 768pt screen minus padding ~= 724pt usable → several columns.
        #expect(GridMath.columns(forWidth: 724, targetCell: 165, gutter: 16) == 4)
    }

    @Test func cellSizeSplitsWidthMinusGutters() {
        // 331 usable, 2 columns, 16 gutter → (331 - 16) / 2 = 157.5
        let size = GridMath.cellSize(forWidth: 331, columns: 2, gutter: 16)
        #expect(abs(size - 157.5) < 0.001)
    }

    @Test func threeColumnBoundary() {
        // ~540pt usable with a 165pt target → (540 + 16) / 181 = 3.07 → 3 columns.
        #expect(GridMath.columns(forWidth: 540, targetCell: 165, gutter: 16) == 3)
    }

    @Test func cellSizeSubtractsAllGuttersForThreeColumns() {
        // 540 usable, 3 columns, 16 gutter → (540 - 16 * 2) / 3 = 169.333…
        let size = GridMath.cellSize(forWidth: 540, columns: 3, gutter: 16)
        #expect(abs(size - 169.3333) < 0.001)
    }

    @Test func zeroWidthIsSafe() {
        // Before first layout pass width is 0; must not crash or go negative.
        #expect(GridMath.columns(forWidth: 0, targetCell: 165, gutter: 16) == 2)
        #expect(GridMath.cellSize(forWidth: 0, columns: 2, gutter: 16) == 0)
    }
}
