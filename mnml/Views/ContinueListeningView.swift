//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI

struct ContinueListeningRoute: Hashable {}

struct ContinueListeningView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerEngine.self) private var engine
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    let onPlay: (Book) -> Void
    let onOpenPlayer: () -> Void
    let onShowDetails: (Book) -> Void

    @State private var store: LibraryStore?
    @State private var pendingDelete: Book?
    @State private var pendingReset: Book?
    @State private var pendingEdit: Book?

    private var inProgress: [Book] {
        books.filter { $0.progressSeconds > 0 }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    private var syncOn: Bool { CloudSyncPreference().isEnabled }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(inProgress) { book in
                    BookRow(
                        book: book,
                        onPlay: onPlay,
                        onOpenPlayer: onOpenPlayer,
                        onShowDetails: onShowDetails,
                        onEdit: { pendingEdit = $0 },
                        onMarkFinished: markFinished,
                        onResetProgress: { pendingReset = $0 },
                        onRemoveDownload: removeDownload,
                        onDelete: { pendingDelete = $0 }
                    )
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, Theme.botSafe + Theme.miniPlayerInset)
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .navigationTitle("Continue Listening")
        .navigationBarTitleDisplayMode(.inline)
        .background(NavTitleFont())
        .task { if store == nil { store = LibraryStore(context: context) } }
        .confirmationDialog(
            "Delete book?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), presenting: pendingDelete
        ) { book in
            Button("Delete", role: .destructive) {
                engine.eject(book)
                store?.delete(book)
            }
            Button("Cancel", role: .cancel) {}
        } message: { book in
            Text(DeleteCopy.single(book.title, syncEnabled: syncOn))
        }
        .confirmationDialog(
            "Reset progress?",
            isPresented: Binding(
                get: { pendingReset != nil },
                set: { if !$0 { pendingReset = nil } }
            ), presenting: pendingReset
        ) { book in
            Button("Reset") { resetProgress(book) }
            Button("Cancel", role: .cancel) {}
        } message: { book in
            Text("“\(book.title)” will start over from the beginning.")
        }
        .sheet(item: $pendingEdit) { book in
            EditBookView(book: book)
        }
    }

    private func markFinished(_ book: Book) {
        engine.markFinished(book)
        try? context.save()
    }

    private func resetProgress(_ book: Book) {
        engine.resetProgress(book)
        try? context.save()
    }

    private func removeDownload(_ book: Book) {
        Haptics.tap()
        engine.releaseDownload(book)
        store?.removeDownload(book)
    }
}
