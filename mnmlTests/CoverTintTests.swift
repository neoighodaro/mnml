//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Testing

@testable import mnml

struct CoverTintTests {
    @Test func assignmentIsDeterministic() {
        // Pinned so a change to FNV constants or `all` order is caught.
        #expect(CoverTint.assign(for: "The Overstory") == "mist")
        #expect(CoverTint.assign(for: "Piranesi") == "plum")
    }

    @Test func assignmentReturnsKnownTint() {
        let name = CoverTint.assign(for: "Piranesi")
        #expect(CoverTint.all.contains(name))
    }

    @Test func emptyTitleStillReturnsTint() {
        #expect(CoverTint.all.contains(CoverTint.assign(for: "")))
    }
}
