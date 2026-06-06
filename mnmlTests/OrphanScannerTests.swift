//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct OrphanScannerTests {
    // A real downloaded book and an evicted one (its hidden iCloud placeholder) both
    // map to live records, so neither is an orphan; only the unclaimed file is.
    @Test func flagsOnlyFilesNoRecordClaims() {
        let disk = ["A.m4b", ".B.m4b.icloud", "stray.m4b"]
        let claimed: Set<String> = ["A.m4b", "B.m4b"]
        #expect(OrphanScanner.orphans(onDisk: disk, claimedBy: claimed) == ["stray.m4b"])
    }

    // The whole point: a book we just evicted lives as `.<uuid>.m4b.icloud`. It must NOT
    // be deleted as an orphan — its record still claims `<uuid>.m4b`.
    @Test func keepsEvictedBookPlaceholder() {
        let disk = [".4B1E.m4b.icloud"]
        #expect(OrphanScanner.orphans(onDisk: disk, claimedBy: ["4B1E.m4b"]).isEmpty)
    }

    // An orphan that itself got evicted exists only as a placeholder; normalizing reveals
    // its logical name is unclaimed, so it's still caught.
    @Test func flagsEvictedOrphanPlaceholder() {
        let disk = [".junk.m4b.icloud"]
        #expect(OrphanScanner.orphans(onDisk: disk, claimedBy: ["A.m4b"]) == [".junk.m4b.icloud"])
    }

    // A stray hidden file (e.g. .DS_Store) belongs to no record and isn't a placeholder,
    // so it's an orphan — harmless to remove.
    @Test func flagsStrayHiddenFile() {
        #expect(OrphanScanner.orphans(onDisk: [".DS_Store"], claimedBy: ["A.m4b"]) == [".DS_Store"])
    }

    @Test func emptyDirectoryHasNoOrphans() {
        #expect(OrphanScanner.orphans(onDisk: [], claimedBy: ["A.m4b"]).isEmpty)
    }

    @Test func logicalNameStripsPlaceholderDecoration() {
        #expect(OrphanScanner.logicalName(of: ".4B1E.m4b.icloud") == "4B1E.m4b")
    }

    @Test func logicalNamePassesPlainNameThrough() {
        #expect(OrphanScanner.logicalName(of: "4B1E.m4b") == "4B1E.m4b")
    }

    // Only the true placeholder shape (leading dot AND .icloud suffix) is decoded; a
    // hidden file that merely starts with a dot is left as-is.
    @Test func logicalNameLeavesNonPlaceholderHiddenFile() {
        #expect(OrphanScanner.logicalName(of: ".DS_Store") == ".DS_Store")
    }
}
