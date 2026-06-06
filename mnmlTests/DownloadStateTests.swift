//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct DownloadStateTests {
    @Test func mapsSystemStatuses() {
        #expect(DownloadState.from(.current) == .downloaded)
        #expect(DownloadState.from(.downloaded) == .downloaded)
        #expect(DownloadState.from(.notDownloaded) == .notDownloaded)
        #expect(DownloadState.from(nil) == .notDownloaded)
    }

    @Test func plainLocalFileCountsAsDownloaded() throws {
        // A non-ubiquitous file (sync off / never in iCloud) is always available.
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dlstate-\(UUID().uuidString).bin")
        try Data([0x1]).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(DownloadState.current(for: tmp) == .downloaded)
    }

    @Test func missingNonUbiquitousFileIsNotDownloaded() {
        // A path with no file on disk (orphaned record / failed migration) must NOT
        // report as downloaded — otherwise the player hands a dead URL to AVPlayer.
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dlstate-missing-\(UUID().uuidString).bin")
        #expect(DownloadState.current(for: missing) == .notDownloaded)
    }

    @Test func canShareWhenLocalFileExists() throws {
        // A real on-disk file (sync off, or downloaded) is shareable.
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("share-\(UUID().uuidString).bin")
        try Data([0x1]).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(DownloadState.current(for: tmp) == .downloaded)
    }

    @Test func cannotShareWhenFileMissing() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("share-missing-\(UUID().uuidString).bin")
        #expect(DownloadState.current(for: missing) == .notDownloaded)
    }

    @Test func canRemoveOnlyWhenSyncedAndDownloaded() {
        #expect(DownloadState.canRemoveDownload(syncEnabled: true, state: .downloaded) == true)
        #expect(DownloadState.canRemoveDownload(syncEnabled: true, state: .notDownloaded) == false)
        #expect(DownloadState.canRemoveDownload(syncEnabled: true, state: .downloading) == false)
        #expect(DownloadState.canRemoveDownload(syncEnabled: false, state: .downloaded) == false)
    }
}
