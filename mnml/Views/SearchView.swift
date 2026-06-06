//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI

/// The Search tab (role: .search). A searchable list of books matching by title
/// or author; tapping a result pushes the same BookDetailView the Library uses.
struct SearchView: View {
    @Environment(PlayerEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    let onOpenPlayer: () -> Void

    @State private var query = ""
    @State private var path = NavigationPath()
    @State private var store: LibraryStore?

    private var results: [Book] { BookSearch.filter(books, query: query) }

    var body: some View {
        NavigationStack(path: $path) {
            List(results) { book in
                Button {
                    Haptics.tap()
                    path.append(book)
                } label: {
                    SearchRow(book: book)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            // The search field for a .search-role tab sits at the BOTTOM, so the top
            // nav bar is dead weight here — and iOS 26 won't reliably render a large
            // title in this configuration anyway. Hide the bar entirely for a clean page.
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if results.isEmpty && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(
                    book: book,
                    onBack: { if !path.isEmpty { path.removeLast() } },
                    onPlay: { seconds in
                        engine.load(book, startAt: seconds)
                        engine.play()
                        onOpenPlayer()
                    },
                    onDelete: {
                        engine.eject(book)
                        store?.delete(book)
                        if !path.isEmpty { path.removeLast() }
                    }
                )
            }
        }
        .background(Theme.bg)
        .searchable(text: $query, prompt: Text("Search"))
        .task { if store == nil { store = LibraryStore(context: context) } }
    }
}

/// A single search result row: cover + title/author, mirroring the library cell look.
private struct SearchRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            CoverView(
                title: book.title, tint: book.tint,
                artworkData: book.artworkData, size: 48, radius: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(Typography.body(15, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text(book.author)
                    .font(Typography.rowAuthor)
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
