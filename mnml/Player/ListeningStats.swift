//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Lifetime listening tallies, persisted in UserDefaults. Append-only: the values only
/// ever increase, so they survive deleting a finished book (unlike anything derived from
/// the current library). Injected into the environment beside `PlayerEngine`; the engine
/// writes, the library reads.
@MainActor
@Observable
final class ListeningStats {
    private let defaults: UserDefaults
    private(set) var totalSecondsListened: Double
    /// IDs of every distinct book ever finished. Stored (not just a count) so that finishing
    /// the same book twice — naturally, then re-marked from the menu — counts once.
    private var finishedBookIDs: Set<String>

    var booksFinished: Int { finishedBookIDs.count }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.totalSecondsListened = defaults.double(forKey: Keys.listened)
        self.finishedBookIDs = Set(defaults.stringArray(forKey: Keys.finished) ?? [])
    }

    /// Credit content-seconds of listening. Non-positive values are ignored.
    func addListened(_ seconds: Double) {
        guard seconds > 0 else { return }
        totalSecondsListened += seconds
        defaults.set(totalSecondsListened, forKey: Keys.listened)
    }

    /// Record a finished book by its stable id. Idempotent — re-finishing the same book
    /// doesn't inflate the count. Append-only, so the tally survives deleting the book.
    func recordFinish(bookID: String) {
        guard finishedBookIDs.insert(bookID).inserted else { return }
        defaults.set(Array(finishedBookIDs), forKey: Keys.finished)
    }

    private enum Keys {
        static let listened = "stats.totalSecondsListened"
        static let finished = "stats.finishedBookIDs"
    }
}
