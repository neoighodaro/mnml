//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation

/// One titled (or untitled, when ungrouped) run of books to render.
struct LibrarySection: Identifiable {
    let title: String?
    let books: [Book]
    var id: String { title ?? "__ungrouped__" }
}

/// Pure transformation of a flat book list into display sections, driven by the
/// user's view options. No SwiftData context, no UI, no disk access — the
/// "downloaded" check is injected so this stays fully unit-testable.
enum LibraryArrangement {

    // MARK: Status heuristic
    // `Book` has no stored "finished" flag; a finished and a never-started book both
    // have progressSeconds == 0. `lastPlayedAt` is the only distinguisher.
    static func isInProgress(_ b: Book) -> Bool { b.progressSeconds > 0 }
    static func isFinished(_ b: Book) -> Bool { b.progressSeconds == 0 && b.lastPlayedAt != nil }
    static func isNotStarted(_ b: Book) -> Bool { b.progressSeconds == 0 && b.lastPlayedAt == nil }

    static func sections(
        books: [Book],
        filter: LibraryFilter,
        sort: LibrarySort,
        direction: SortDirection,
        grouping: LibraryGrouping,
        isDownloaded: (Book) -> Bool
    ) -> [LibrarySection] {
        let filtered = books.filter { passes($0, filter: filter, isDownloaded: isDownloaded) }
        let sorted = sortBooks(filtered, sort: sort, direction: direction)
        return group(sorted, by: grouping)
    }

    // MARK: Filter
    private static func passes(
        _ b: Book, filter: LibraryFilter,
        isDownloaded: (Book) -> Bool
    ) -> Bool {
        switch filter {
        case .all: return true
        case .inProgress: return isInProgress(b)
        case .finished: return isFinished(b)
        case .notStarted: return isNotStarted(b)
        case .downloaded: return isDownloaded(b)
        }
    }

    // MARK: Sort
    private static func sortBooks(
        _ books: [Book], sort: LibrarySort,
        direction: SortDirection
    ) -> [Book] {
        let asc = direction == .ascending
        switch sort {
        case .title:
            return books.sorted { ordered($0.title, $1.title, asc) }
        case .author:
            return books.sorted { ordered($0.author, $1.author, asc) }
        case .dateAdded:
            return books.sorted { compare($0.dateAdded, $1.dateAdded, asc) }
        case .recentlyPlayed:
            return books.sorted {
                compare($0.lastPlayedAt ?? .distantPast, $1.lastPlayedAt ?? .distantPast, asc)
            }
        case .duration:
            return books.sorted { compare($0.durationSeconds, $1.durationSeconds, asc) }
        }
    }

    private static func compare<T: Comparable>(_ a: T, _ b: T, _ asc: Bool) -> Bool {
        asc ? a < b : a > b
    }

    private static func ordered(_ a: String, _ b: String, _ asc: Bool) -> Bool {
        let result = a.localizedCaseInsensitiveCompare(b)
        return asc ? result == .orderedAscending : result == .orderedDescending
    }

    // MARK: Group (input already sorted; grouping preserves that order within a section)
    private static func group(_ books: [Book], by grouping: LibraryGrouping) -> [LibrarySection] {
        switch grouping {
        case .none:
            return [LibrarySection(title: nil, books: books)]

        case .author:
            // Preserve first-seen order of books, then order the sections by author name.
            var order: [String] = []
            var buckets: [String: [Book]] = [:]
            for b in books {
                if buckets[b.author] == nil { order.append(b.author) }
                buckets[b.author, default: []].append(b)
            }
            return
                order
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .map { LibrarySection(title: $0, books: buckets[$0] ?? []) }

        case .status:
            // Fixed display order; empty sections omitted.
            let inProgress = books.filter { isInProgress($0) }
            let finished = books.filter { isFinished($0) }
            let notStarted = books.filter { isNotStarted($0) }
            return [
                ("In Progress", inProgress),
                ("Finished", finished),
                ("Not Started", notStarted),
            ]
            .filter { !$0.1.isEmpty }
            .map { LibrarySection(title: $0.0, books: $0.1) }
        }
    }
}
