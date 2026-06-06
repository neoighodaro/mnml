//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Pure helpers for the Edit Book Details sheet: whitespace trimming, narrator
/// normalization (empty → nil), and the Save-button gate. UI-free and unit-testable.
enum BookEdit {
    static func clean(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trimmed narrator, or nil when blank — matches `Book.narrator` being optional.
    static func normalizedNarrator(_ s: String) -> String? {
        let trimmed = clean(s)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Save is allowed only when something changed and the title isn't blank.
    static func canSave(title: String, hasChanges: Bool) -> Bool {
        hasChanges && !clean(title).isEmpty
    }
}
