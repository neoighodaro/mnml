//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import CoreGraphics

/// Layout math for the responsive library grid. Pure functions so the column logic
/// is unit-testable independently of SwiftUI.
enum GridMath {
    /// Number of columns that fit `width`, never fewer than 2.
    /// `targetCell` is the preferred minimum cell width; `gutter` is inter-cell spacing.
    static func columns(forWidth width: CGFloat, targetCell: CGFloat, gutter: CGFloat) -> Int {
        guard width > 0 else { return 2 }
        let fit = Int((width + gutter) / (targetCell + gutter))
        return max(2, fit)
    }

    /// Exact square cell width once `columns` is known. Returns 0 for non-positive width.
    static func cellSize(forWidth width: CGFloat, columns: Int, gutter: CGFloat) -> CGFloat {
        guard width > 0, columns > 0 else { return 0 }
        return (width - gutter * CGFloat(columns - 1)) / CGFloat(columns)
    }
}
