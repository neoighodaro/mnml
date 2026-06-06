//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Single source of truth for "is this audiobook already in the library".
/// Matches on title + author + duration (rounded to the nearest second),
/// case-insensitive and whitespace-trimmed. If either side has no author,
/// matches on title + duration alone — so a missing author on one import
/// doesn't let an otherwise-identical book slip in as a duplicate.
enum DuplicateMatcher {
    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isDuplicate(
        title: String, author: String, duration: Double,
        against existing: [(title: String, author: String, duration: Double)]
    ) -> Bool {
        let t = normalize(title)
        let a = normalize(author)
        let d = duration.rounded()
        return existing.contains { e in
            guard normalize(e.title) == t, e.duration.rounded() == d else { return false }
            let ea = normalize(e.author)
            if a.isEmpty || ea.isEmpty { return true }
            return ea == a
        }
    }
}
