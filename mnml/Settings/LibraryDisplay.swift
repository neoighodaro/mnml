//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// UserDefaults keys backing the library view options (read via `@AppStorage`).
enum LibraryDisplayKeys {
    static let sort = "librarySort"
    static let direction = "librarySortDirection"
    static let grouping = "libraryGrouping"
    static let filter = "libraryFilter"
    static let layout = "libraryLayout"
}

/// How books are ordered on the full library page.
enum LibrarySort: String, CaseIterable, Identifiable {
    case dateAdded, title, author, recentlyPlayed, duration
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dateAdded: return "Date Added"
        case .title: return "Title"
        case .author: return "Author"
        case .recentlyPlayed: return "Recently Played"
        case .duration: return "Duration"
        }
    }
}

enum SortDirection: String, CaseIterable, Identifiable {
    case ascending, descending
    var id: String { rawValue }
    var label: String { self == .ascending ? "Ascending" : "Descending" }
}

/// How books are grouped into sections.
enum LibraryGrouping: String, CaseIterable, Identifiable {
    case none, author, status
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .author: return "Author"
        case .status: return "Status"
        }
    }
}

/// Which subset of books is shown.
enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, inProgress, finished, notStarted, downloaded
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .inProgress: return "In Progress"
        case .finished: return "Finished"
        case .notStarted: return "Not Started"
        case .downloaded: return "Downloaded"
        }
    }
}

/// Grid of covers vs. a list of rows.
enum LibraryLayout: String, CaseIterable, Identifiable {
    case grid, list
    var id: String { rawValue }
    var label: String { self == .grid ? "Grid" : "List" }
}
