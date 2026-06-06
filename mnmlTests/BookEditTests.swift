//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct BookEditTests {
    @Test func cleanTrimsWhitespace() {
        #expect(BookEdit.clean("  Dune  ") == "Dune")
        #expect(BookEdit.clean("\n Piranesi \t") == "Piranesi")
    }

    @Test func normalizedNarratorIsNilWhenEmpty() {
        #expect(BookEdit.normalizedNarrator("   ") == nil)
        #expect(BookEdit.normalizedNarrator("") == nil)
        #expect(BookEdit.normalizedNarrator("  Rosamund Pike ") == "Rosamund Pike")
    }

    @Test func canSaveRequiresChangeAndNonEmptyTitle() {
        #expect(BookEdit.canSave(title: "Dune", hasChanges: true) == true)
        #expect(BookEdit.canSave(title: "Dune", hasChanges: false) == false)  // nothing changed
        #expect(BookEdit.canSave(title: "   ", hasChanges: true) == false)  // empty title
        #expect(BookEdit.canSave(title: "", hasChanges: true) == false)
    }
}
