//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

@MainActor
struct ListeningStatsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "test.listeningstats.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func startsAtZero() {
        let stats = ListeningStats(defaults: freshDefaults())
        #expect(stats.totalSecondsListened == 0)
        #expect(stats.booksFinished == 0)
    }

    @Test func addListenedAccumulates() {
        let stats = ListeningStats(defaults: freshDefaults())
        stats.addListened(30)
        stats.addListened(15)
        #expect(stats.totalSecondsListened == 45)
    }

    @Test func addListenedIgnoresNonPositive() {
        let stats = ListeningStats(defaults: freshDefaults())
        stats.addListened(0)
        stats.addListened(-10)
        #expect(stats.totalSecondsListened == 0)
    }

    @Test func recordFinishCountsDistinctBooks() {
        let stats = ListeningStats(defaults: freshDefaults())
        stats.recordFinish(bookID: "a")
        stats.recordFinish(bookID: "b")
        #expect(stats.booksFinished == 2)
    }

    @Test func recordFinishIsIdempotentPerBook() {
        let stats = ListeningStats(defaults: freshDefaults())
        stats.recordFinish(bookID: "a")
        stats.recordFinish(bookID: "a")
        #expect(stats.booksFinished == 1)
    }

    @Test func valuesPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = ListeningStats(defaults: defaults)
        first.addListened(120)
        first.recordFinish(bookID: "a")

        let second = ListeningStats(defaults: defaults)
        #expect(second.totalSecondsListened == 120)
        #expect(second.booksFinished == 1)
        second.recordFinish(bookID: "a")  // already finished — stays at 1
        #expect(second.booksFinished == 1)
    }
}
