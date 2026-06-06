//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct ImportSummaryTests {
    @Test func zeroFoundIsNothingFound() {
        #expect(ImportSummary().notice == .nothingFound)
    }

    @Test func allImportedIsAdded() {
        let s = ImportSummary(imported: 3, skipped: 0, failed: 0)
        #expect(s.notice == .added(3))
    }

    @Test func importedWithSkipsAndFailures() {
        let s = ImportSummary(imported: 4, skipped: 1, failed: 1)
        #expect(s.notice == .addedWithIssues(added: 4, skipped: 1, failed: 1))
    }

    @Test func importedWithSkipsOnly() {
        let s = ImportSummary(imported: 2, skipped: 1, failed: 0)
        #expect(s.notice == .addedWithIssues(added: 2, skipped: 1, failed: 0))
    }

    @Test func skippedOnlyIsNoneAdded() {
        let s = ImportSummary(imported: 0, skipped: 2, failed: 0)
        #expect(s.notice == .noneAdded(skipped: 2, failed: 0))
    }

    @Test func failedOnlyIsNoneAdded() {
        let s = ImportSummary(imported: 0, skipped: 0, failed: 3)
        #expect(s.notice == .noneAdded(skipped: 0, failed: 3))
    }

    @Test func skippedAndFailedIsNoneAdded() {
        let s = ImportSummary(imported: 0, skipped: 1, failed: 2)
        #expect(s.notice == .noneAdded(skipped: 1, failed: 2))
    }
}
