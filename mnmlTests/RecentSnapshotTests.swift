//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct RecentSnapshotTests {
    @Test func roundTripsThroughJSON() throws {
        let snap = RecentSnapshot(
            bookID: "abc", title: "Darknet Diaries",
            author: "Jack Rhysider", tint: "clay",
            isPlaying: true, hasArtwork: true)
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(RecentSnapshot.self, from: data)
        #expect(decoded == snap)
    }

    @Test func emptyHelperHasNoBook() {
        #expect(RecentSnapshot.empty.isEmpty)
        #expect(
            !RecentSnapshot(
                bookID: "x", title: "t", author: "a",
                tint: "clay", isPlaying: false, hasArtwork: false
            )
            .isEmpty)
    }
}
