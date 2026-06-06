//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct WidgetSnapshotStoreTests {
    private func makeStore() throws -> (WidgetSnapshotStore, URL) {
        let suiteName = "test.widget.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (WidgetSnapshotStore(defaults: defaults, containerDir: dir), dir)
    }

    @Test func readsEmptyWhenNothingWritten() throws {
        let (store, _) = try makeStore()
        #expect(store.read() == RecentSnapshot.empty)
    }

    @Test func writeThenReadRoundTrips() throws {
        let (store, _) = try makeStore()
        let snap = RecentSnapshot(
            bookID: "id1", title: "T", author: "A",
            tint: "plum", isPlaying: true, hasArtwork: false)
        store.write(snap)
        #expect(store.read() == snap)
    }

    @Test func writeArtworkPersistsAndLoads() throws {
        let (store, _) = try makeStore()
        // A 1x1 JPEG's bytes aren't needed; store writes raw Data and reads it back.
        let bytes = Data([0x01, 0x02, 0x03])
        store.writeArtwork(bytes)
        #expect(store.readArtworkData() == bytes)
    }

    @Test func clearArtworkRemovesFile() throws {
        let (store, _) = try makeStore()
        store.writeArtwork(Data([0x09]))
        store.writeArtwork(nil)  // nil clears
        #expect(store.readArtworkData() == nil)
    }
}
