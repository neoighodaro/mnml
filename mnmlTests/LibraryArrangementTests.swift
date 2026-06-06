//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct LibraryArrangementTests {

    // Build a detached Book (no ModelContext needed) with just the fields we sort/filter on.
    private func book(
        _ title: String, author: String = "A", progress: Double = 0,
        lastPlayed: Date? = nil, added: Date = .distantPast,
        duration: Double = 0
    ) -> Book {
        let b = Book()
        b.title = title
        b.author = author
        b.progressSeconds = progress
        b.lastPlayedAt = lastPlayed
        b.dateAdded = added
        b.durationSeconds = duration
        return b
    }

    private let notDownloaded: (Book) -> Bool = { _ in false }

    // One headerless section when grouping is none.
    @Test func groupingNoneYieldsSingleUntitledSection() {
        let books = [book("A"), book("B")]
        let sections = LibraryArrangement.sections(
            books: books, filter: .all, sort: .title, direction: .ascending,
            grouping: .none, isDownloaded: notDownloaded)
        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(sections[0].books.map(\.title) == ["A", "B"])
    }

    @Test func titleSortRespectsDirection() {
        let books = [book("Banana"), book("apple"), book("Cherry")]
        let asc = LibraryArrangement.sections(
            books: books, filter: .all, sort: .title, direction: .ascending,
            grouping: .none, isDownloaded: notDownloaded)
        #expect(asc[0].books.map(\.title) == ["apple", "Banana", "Cherry"])
        let desc = LibraryArrangement.sections(
            books: books, filter: .all, sort: .title, direction: .descending,
            grouping: .none, isDownloaded: notDownloaded)
        #expect(desc[0].books.map(\.title) == ["Cherry", "Banana", "apple"])
    }

    @Test func dateAddedSortDescending() {
        let old = book("Old", added: Date(timeIntervalSince1970: 100))
        let new = book("New", added: Date(timeIntervalSince1970: 200))
        let sections = LibraryArrangement.sections(
            books: [old, new], filter: .all, sort: .dateAdded, direction: .descending,
            grouping: .none, isDownloaded: notDownloaded)
        #expect(sections[0].books.map(\.title) == ["New", "Old"])
    }

    @Test func recentlyPlayedTreatsNeverPlayedAsOldest() {
        let played = book("Played", lastPlayed: Date(timeIntervalSince1970: 500))
        let never = book("Never", lastPlayed: nil)
        let sections = LibraryArrangement.sections(
            books: [never, played], filter: .all, sort: .recentlyPlayed,
            direction: .descending, grouping: .none, isDownloaded: notDownloaded)
        #expect(sections[0].books.map(\.title) == ["Played", "Never"])
    }

    @Test func durationSortAscending() {
        let sections = LibraryArrangement.sections(
            books: [book("Long", duration: 300), book("Short", duration: 100)],
            filter: .all, sort: .duration, direction: .ascending,
            grouping: .none, isDownloaded: notDownloaded)
        #expect(sections[0].books.map(\.title) == ["Short", "Long"])
    }

    @Test func filterInProgressKeepsOnlyStarted() {
        let started = book("Started", progress: 10)
        let fresh = book("Fresh", progress: 0)
        let sections = LibraryArrangement.sections(
            books: [started, fresh], filter: .inProgress, sort: .title,
            direction: .ascending, grouping: .none, isDownloaded: notDownloaded)
        #expect(sections.flatMap(\.books).map(\.title) == ["Started"])
    }

    @Test func filterFinishedUsesLastPlayedHeuristic() {
        let finished = book("Done", progress: 0, lastPlayed: Date(timeIntervalSince1970: 1))
        let neverStarted = book("Fresh", progress: 0, lastPlayed: nil)
        let inProgress = book("Going", progress: 5, lastPlayed: Date(timeIntervalSince1970: 2))
        let sections = LibraryArrangement.sections(
            books: [finished, neverStarted, inProgress], filter: .finished, sort: .title,
            direction: .ascending, grouping: .none, isDownloaded: notDownloaded)
        #expect(sections.flatMap(\.books).map(\.title) == ["Done"])
    }

    @Test func filterNotStartedUsesLastPlayedHeuristic() {
        let finished = book("Done", progress: 0, lastPlayed: Date(timeIntervalSince1970: 1))
        let neverStarted = book("Fresh", progress: 0, lastPlayed: nil)
        let sections = LibraryArrangement.sections(
            books: [finished, neverStarted], filter: .notStarted, sort: .title,
            direction: .ascending, grouping: .none, isDownloaded: notDownloaded)
        #expect(sections.flatMap(\.books).map(\.title) == ["Fresh"])
    }

    @Test func filterDownloadedUsesInjectedClosure() {
        let a = book("A")
        let b = book("B")
        let onlyA: (Book) -> Bool = { $0.title == "A" }
        let sections = LibraryArrangement.sections(
            books: [a, b], filter: .downloaded, sort: .title,
            direction: .ascending, grouping: .none, isDownloaded: onlyA)
        #expect(sections.flatMap(\.books).map(\.title) == ["A"])
    }

    @Test func groupingByAuthorMakesSortedSectionsPerAuthor() {
        let books = [
            book("Z", author: "Zadie"),
            book("A", author: "Adam"),
            book("M", author: "Adam"),
        ]
        let sections = LibraryArrangement.sections(
            books: books, filter: .all, sort: .title, direction: .ascending,
            grouping: .author, isDownloaded: notDownloaded)
        #expect(sections.map(\.title) == ["Adam", "Zadie"])
        #expect(sections[0].books.map(\.title) == ["A", "M"])
        #expect(sections[1].books.map(\.title) == ["Z"])
    }

    @Test func groupingByStatusUsesFixedOrderAndOmitsEmpty() {
        let inProgress = book("Going", progress: 5)
        let finished = book("Done", progress: 0, lastPlayed: Date(timeIntervalSince1970: 1))
        // No "Not Started" book -> that section is omitted.
        let sections = LibraryArrangement.sections(
            books: [finished, inProgress], filter: .all, sort: .title,
            direction: .ascending, grouping: .status, isDownloaded: notDownloaded)
        #expect(sections.map(\.title) == ["In Progress", "Finished"])
        #expect(sections[0].books.map(\.title) == ["Going"])
        #expect(sections[1].books.map(\.title) == ["Done"])
    }
}
