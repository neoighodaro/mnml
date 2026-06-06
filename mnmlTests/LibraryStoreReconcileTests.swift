//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct LibraryStoreReconcileTests {
    private func book(progress: Double, added: Date) -> Book {
        let b = Book()
        b.progressSeconds = progress
        b.dateAdded = added
        return b
    }

    @Test func survivorKeepsFurthestProgress() {
        let behind = book(progress: 100, added: Date(timeIntervalSince1970: 0))
        let ahead = book(progress: 900, added: Date(timeIntervalSince1970: 10))
        #expect(LibraryStore.survivor(of: [behind, ahead])?.id == ahead.id)
    }

    @Test func survivorBreaksTieByEarliestDateAdded() {
        let older = book(progress: 100, added: Date(timeIntervalSince1970: 0))
        let newer = book(progress: 100, added: Date(timeIntervalSince1970: 10))
        #expect(LibraryStore.survivor(of: [newer, older])?.id == older.id)
    }

    @Test func survivorOfEmptyIsNil() {
        #expect(LibraryStore.survivor(of: []) == nil)
    }
}
