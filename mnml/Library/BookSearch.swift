//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Pure, view-independent search matching for the library. Kept separate from any
/// SwiftUI/SwiftData type so it can be unit-tested over plain strings.
enum BookSearch {
    /// True when `query` (trimmed) is contained in the title or author, ignoring
    /// case and diacritics. An empty/whitespace query matches everything.
    static func matches(query: String, title: String, author: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return title.localizedStandardContains(q) || author.localizedStandardContains(q)
    }

    /// Filter a list of books by `query`, preserving the input order.
    static func filter(_ books: [Book], query: String) -> [Book] {
        books.filter { matches(query: query, title: $0.title, author: $0.author) }
    }
}
