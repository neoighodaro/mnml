//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct ImportProgressTests {
    @Test func idleIsNotActive() {
        #expect(ImportProgress.idle.isActive == false)
    }

    @Test func singleIsActive() {
        #expect(ImportProgress.single.isActive == true)
    }

    @Test func folderIsActive() {
        #expect(ImportProgress.folder(completed: 0, total: 5).isActive == true)
    }

    @Test func singleLabelIsIndeterminate() {
        #expect(ImportProgress.single.label == "Importing…")
        #expect(ImportProgress.single.fraction == nil)
    }

    @Test func folderLabelShowsCount() {
        let p = ImportProgress.folder(completed: 3, total: 12)
        #expect(p.label == "Importing 3 of 12…")
        #expect(p.fraction == 0.25)
    }

    @Test func folderWithZeroTotalHasNoFraction() {
        // Guards against divide-by-zero on an empty folder.
        let p = ImportProgress.folder(completed: 0, total: 0)
        #expect(p.fraction == nil)
    }

    @Test func idleHasNoFraction() {
        #expect(ImportProgress.idle.fraction == nil)
    }
}
