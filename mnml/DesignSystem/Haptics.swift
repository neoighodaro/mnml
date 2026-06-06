//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import UIKit

/// Lightweight wrapper over `UIImpactFeedbackGenerator` so button taps share one
/// consistent feel. Each call spins up a generator on demand — fine for the
/// occasional, user-initiated taps these buttons produce.
enum Haptics {
    /// A light impact for general button presses — row taps, transport, navigation.
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
