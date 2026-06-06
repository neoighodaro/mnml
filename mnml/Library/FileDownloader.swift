//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Materializes and evicts ubiquitous audiobook files. Reads go through
/// `DownloadState.current(for:)`; `ensureDownloaded` requests a download and waits
/// until the local copy lands. A non-ubiquitous file (local-only mode) is already
/// available, so `ensureDownloaded` returns immediately for it.
enum FileDownloader {
    enum DownloadError: Error { case timedOut }

    static func isDownloaded(at url: URL) -> Bool {
        DownloadState.current(for: url) == .downloaded
    }

    /// Returns once `url` is downloaded. No-op if already local. Throws `.timedOut`
    /// after ~60s so the player can surface an error instead of hanging forever.
    static func ensureDownloaded(at url: URL) async throws {
        if isDownloaded(at: url) { return }
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        for _ in 0..<600 {
            try Task.checkCancellation()
            if isDownloaded(at: url) { return }
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
        }
        throw DownloadError.timedOut
    }

    /// Removes this device's local copy without deleting the iCloud original. Runs the
    /// eviction off the main thread — `evictUbiquitousItem` does coordinated file I/O
    /// that can briefly block, which freezes the UI if called on the main actor.
    static func evict(at url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.evictUbiquitousItem(at: url)
        }
        .value
    }
}
