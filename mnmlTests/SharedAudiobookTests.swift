//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct SharedAudiobookTests {
    @Test func normalTitleBecomesNamedM4B() {
        #expect(SharedAudiobook.suggestedFileName(for: "The Hobbit") == "The Hobbit.m4b")
    }

    @Test func stripsPathHostileCharacters() {
        let name = SharedAudiobook.suggestedFileName(for: "A/B: C? \"D\"")
        #expect(!name.dropLast(4).contains("/"))  // drop the ".m4b" before checking
        #expect(!name.contains(":"))
        #expect(!name.contains("?"))
        #expect(!name.contains("\""))
        #expect(name.hasSuffix(".m4b"))
    }

    @Test func emptyTitleFallsBackToAudiobook() {
        #expect(SharedAudiobook.suggestedFileName(for: "") == "Audiobook.m4b")
    }

    @Test func whitespaceOnlyTitleFallsBackToAudiobook() {
        #expect(SharedAudiobook.suggestedFileName(for: "   ") == "Audiobook.m4b")
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(SharedAudiobook.suggestedFileName(for: "  Dune  ") == "Dune.m4b")
    }
}
