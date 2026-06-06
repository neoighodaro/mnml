//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct BookSearchTests {
    @Test func emptyQueryMatchesEverything() {
        #expect(BookSearch.matches(query: "", title: "Dune", author: "Herbert"))
        #expect(BookSearch.matches(query: "   ", title: "Dune", author: "Herbert"))
    }

    @Test func matchesTitleCaseInsensitive() {
        #expect(BookSearch.matches(query: "dun", title: "Dune", author: "Herbert"))
        #expect(BookSearch.matches(query: "DUNE", title: "Dune", author: "Herbert"))
    }

    @Test func matchesAuthor() {
        #expect(BookSearch.matches(query: "herb", title: "Dune", author: "Frank Herbert"))
    }

    @Test func matchesDiacriticInsensitive() {
        #expect(BookSearch.matches(query: "bronte", title: "Jane Eyre", author: "Brontë"))
    }

    @Test func noMatchReturnsFalse() {
        #expect(!BookSearch.matches(query: "zzz", title: "Dune", author: "Herbert"))
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(BookSearch.matches(query: "  dune  ", title: "Dune", author: "Herbert"))
    }
}
