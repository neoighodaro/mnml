//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct DuplicateMatcherTests {
    typealias Existing = (title: String, author: String, duration: Double)

    @Test func matchesIdenticalBook() {
        let existing: [Existing] = [("Dune", "Frank Herbert", 75600)]
        #expect(
            DuplicateMatcher.isDuplicate(
                title: "Dune", author: "Frank Herbert",
                duration: 75600, against: existing))
    }

    @Test func ignoresCaseAndWhitespace() {
        let existing: [Existing] = [("Dune", "Frank Herbert", 75600)]
        #expect(
            DuplicateMatcher.isDuplicate(
                title: "  dune ", author: "FRANK HERBERT",
                duration: 75600, against: existing))
    }

    @Test func roundsDurationToNearestSecond() {
        let existing: [Existing] = [("Dune", "Frank Herbert", 75600.0)]
        #expect(
            DuplicateMatcher.isDuplicate(
                title: "Dune", author: "Frank Herbert",
                duration: 75600.4, against: existing))
    }

    @Test func differentDurationIsNotDuplicate() {
        let existing: [Existing] = [("Dune", "Frank Herbert", 75600)]
        #expect(
            !DuplicateMatcher.isDuplicate(
                title: "Dune", author: "Frank Herbert",
                duration: 70000, against: existing))
    }

    @Test func differentTitleIsNotDuplicate() {
        let existing: [Existing] = [("Dune", "Frank Herbert", 75600)]
        #expect(
            !DuplicateMatcher.isDuplicate(
                title: "Dune Messiah", author: "Frank Herbert",
                duration: 75600, against: existing))
    }

    @Test func emptyCandidateAuthorMatchesOnTitleAndDuration() {
        // When the candidate has no author, match on title + duration only.
        let existing: [Existing] = [("Dune", "Frank Herbert", 75600)]
        #expect(
            DuplicateMatcher.isDuplicate(
                title: "Dune", author: "",
                duration: 75600, against: existing))
    }

    @Test func emptyExistingAuthorMatchesOnTitleAndDuration() {
        // When the existing book has no author, a candidate that does have one
        // still matches on title + duration — the blank side is the wildcard.
        let existing: [Existing] = [("Dune", "", 75600)]
        #expect(
            DuplicateMatcher.isDuplicate(
                title: "Dune", author: "Frank Herbert",
                duration: 75600, against: existing))
    }

    @Test func emptyLibraryIsNeverDuplicate() {
        #expect(
            !DuplicateMatcher.isDuplicate(
                title: "Dune", author: "Frank Herbert",
                duration: 75600, against: []))
    }
}
