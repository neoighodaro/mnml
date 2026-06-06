//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation

/// Moves audiobook files from local `Books/` into the iCloud Drive container's
/// `Books/`. A MOVE (not copy) is what guarantees a single source of truth — no
/// file ever sits in both places. Idempotent and best-effort per file:
///  - destination already has the file → drop the local duplicate, skip;
///  - one file failing to move doesn't abort the rest;
///  - safe to re-run on every launch (remaining files migrate next time).
///
/// Does blocking file I/O — call OFF the main thread. Uses `NSFileCoordinator`
/// because the destination is a ubiquitous location iCloud is watching.
enum BookFileMigrator {
    static func migrate(from localBooks: URL, to cloudBooks: URL) {
        let fm = FileManager.default
        guard
            let items = try? fm.contentsOfDirectory(
                at: localBooks, includingPropertiesForKeys: nil)
        else { return }
        try? fm.createDirectory(at: cloudBooks, withIntermediateDirectories: true)

        let coordinator = NSFileCoordinator(filePresenter: nil)
        for src in items {
            let dest = cloudBooks.appendingPathComponent(src.lastPathComponent)
            // Only treat the destination as "already migrated" when it is a COMPLETE copy
            // (same logical size as the local original). A leftover zero-byte/partial file
            // from an interrupted move would otherwise cause us to delete the intact local
            // original and strand the user with the incomplete copy.
            if fm.fileExists(atPath: dest.path), sameContentSize(src, dest, using: fm) {
                try? fm.removeItem(at: src)  // already fully migrated — drop the local duplicate
                continue
            }
            var coordError: NSError?
            coordinator.coordinate(
                writingItemAt: src, options: .forMoving,
                writingItemAt: dest, options: .forReplacing,
                error: &coordError
            ) { srcURL, destURL in
                try? fm.removeItem(at: destURL)  // clear any partial/stub leftover so the move can land
                try? fm.moveItem(at: srcURL, to: destURL)
            }
        }
    }

    /// True when both files exist and report the same non-zero logical content size —
    /// our proxy for "the destination is a complete copy of the source". `fileSize` is
    /// the logical size (reported even for an iCloud placeholder of a fully-uploaded
    /// file), so a partially-written or zero-byte stub fails this check.
    private static func sameContentSize(_ a: URL, _ b: URL, using fm: FileManager) -> Bool {
        let sizeA = (try? a.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        let sizeB = (try? b.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        guard let sizeA, let sizeB, sizeA > 0 else { return false }
        return sizeA == sizeB
    }
}
