//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// How the Settings sync row should present, derived from the stored preference and
/// the live account availability. Extracted as a pure function so the "don't imply
/// sync is on when it isn't" logic is unit-testable without CloudKit or SwiftUI.
///
///   - `active`       pref on + account available — sync is really happening
///   - `off`          pref off + account available — user can turn it on
///   - `paused`       pref on but no usable account — intent kept, sync suspended
///   - `signInPrompt` pref off + no usable account — must sign in first
enum SyncRowState: Equatable {
    case active
    case off
    case paused
    case signInPrompt

    static func resolve(
        prefEnabled: Bool,
        availability: ICloudAccountMonitor.Availability
    ) -> SyncRowState {
        switch (prefEnabled, availability == .available) {
        case (true, true): return .active
        case (false, true): return .off
        case (true, false): return .paused
        case (false, false): return .signInPrompt
        }
    }
}
