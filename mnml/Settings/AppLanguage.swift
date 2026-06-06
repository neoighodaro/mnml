//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// The user's selected UI language. `rawValue` is the locale/`.lproj` code.
enum AppLanguage: String, CaseIterable {
    case en, de

    /// Shown in the language picker in its own language (never translated).
    var displayName: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        }
    }
}
