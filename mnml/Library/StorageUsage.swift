//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Measures how much room the audiobook library takes. Two figures:
///   - `libraryBytes`    — the logical size of every book, whether it's downloaded here
///                         or lives only in iCloud (the whole-library total).
///   - `downloadedBytes` — what's actually materialized on THIS device's disk right now.
///
/// Both come from one walk of the active `Books/` directory. `fileSize` is the file's
/// logical content size (reported for an iCloud placeholder too, so cloud-only books
/// still count toward the library total); `totalFileAllocatedSize` is the bytes actually
/// on disk, which collapses to ~0 for an evicted placeholder — exactly the device figure.
nonisolated enum StorageUsage {
    struct Totals: Equatable {
        var libraryBytes: Int64 = 0
        var downloadedBytes: Int64 = 0
    }

    private static let keys: Set<URLResourceKey> = [
        .fileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey,
    ]

    /// Walks `Books/` off the main thread and tallies both figures. Best-effort: an
    /// unreadable entry is skipped rather than failing the whole measurement.
    static func measure() async -> Totals {
        await Task.detached(priority: .utility) {
            let dir = M4BImporter.booksDirectory
            guard
                let urls = try? FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: Array(keys))
            else { return Totals() }

            var totals = Totals()
            for url in urls {
                guard let values = try? url.resourceValues(forKeys: keys),
                    values.isRegularFile == true
                else { continue }
                totals.libraryBytes += Int64(values.fileSize ?? 0)
                totals.downloadedBytes += Int64(values.totalFileAllocatedSize ?? 0)
            }
            return totals
        }
        .value
    }
}
