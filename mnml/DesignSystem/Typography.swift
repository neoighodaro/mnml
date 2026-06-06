//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI

/// Type roles from the handoff "Typography" table. `display` = Space Grotesk,
/// body/UI = Inter. SwiftUI maps weight 550 → .medium, 450 → .regular.
enum Typography {
    static func display(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom("Space Grotesk", size: size).weight(weight)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    // named roles
    static let wordmark = display(17, weight: .medium)  // -0.04em tracking applied at call site
    static let eyebrow = display(11, weight: .semibold)  // UPPERCASE, 0.22em tracking
    static let rowTitle = body(16, weight: .medium)
    static let rowAuthor = body(12.5)
    static let detailH1 = display(27, weight: .medium)
    static let playerH1 = display(20, weight: .medium)
    static let chapterTitle = body(15)
    static let chapterNum = body(13)  // tabular
    static let times = body(11.5)  // tabular
    static let buttonLabel = body(15, weight: .medium)
    static let speedValue = display(13.5, weight: .medium)  // tabular
}

extension View {
    /// Uppercase eyebrow label in tertiary color with wide tracking.
    func eyebrowStyle() -> some View {
        self.font(Typography.eyebrow)
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundStyle(Theme.text3)
    }
}
