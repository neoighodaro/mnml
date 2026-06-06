//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Decides which files in `Books/` belong to no audiobook record — leftovers from
/// interrupted iCloud moves, merged-record dedup, or a stray file dropped into the
/// app's iCloud Drive folder by hand. These count toward the storage figures and keep
/// "Free Up Space" from reaching zero, yet no record will ever evict them.
///
/// Pure and `nonisolated` so the rule is unit-testable without touching disk: the
/// caller supplies the directory listing and the set of names records still claim;
/// this just compares them.
nonisolated enum OrphanScanner {
    /// On-disk names that map to no record, preserving input order — safe to delete.
    static func orphans(onDisk diskNames: [String], claimedBy claimed: Set<String>) -> [String] {
        diskNames.filter { !claimed.contains(logicalName(of: $0)) }
    }

    /// Maps an on-disk name back to the record name it stands for. An evicted or
    /// cloud-only book `<uuid>.m4b` lives on disk as the hidden iCloud placeholder
    /// `.<uuid>.m4b.icloud`; strip that decoration so a downloaded book we just evicted
    /// isn't then mistaken for an orphan. Every other name passes through unchanged.
    static func logicalName(of diskName: String) -> String {
        guard diskName.hasPrefix("."), diskName.hasSuffix(".icloud") else { return diskName }
        return String(diskName.dropFirst().dropLast(".icloud".count))
    }
}
