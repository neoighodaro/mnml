//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftData
import SwiftUI

/// The Library tab's content: every book, arranged by the user's view options
/// (sort / group / filter / layout), with multi-select batch delete. Mirrors
/// ContinueListeningView's inline-title shell.
struct FullLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerEngine.self) private var engine
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    let onPlay: (Book) -> Void
    let onOpenPlayer: () -> Void
    let onShowDetails: (Book) -> Void

    @AppStorage(LibraryDisplayKeys.sort) private var sort: LibrarySort = .dateAdded
    @AppStorage(LibraryDisplayKeys.direction) private var direction: SortDirection = .descending
    @AppStorage(LibraryDisplayKeys.grouping) private var grouping: LibraryGrouping = .none
    @AppStorage(LibraryDisplayKeys.filter) private var filter: LibraryFilter = .all
    @AppStorage(LibraryDisplayKeys.layout) private var layout: LibraryLayout = .grid

    @State private var store: LibraryStore?
    @State private var pendingDelete: Book?
    @State private var pendingReset: Book?
    @State private var pendingEdit: Book?
    @State private var isSelecting = false
    @State private var selection = Set<UUID>()
    @State private var pendingBatchDelete = false
    @State private var gridWidth: CGFloat = 0

    private let gridTargetCell: CGFloat = 165
    private let gridGutter: CGFloat = 16

    private var syncOn: Bool { CloudSyncPreference().isEnabled }

    private var sections: [LibrarySection] {
        LibraryArrangement.sections(
            books: books, filter: filter, sort: sort, direction: direction,
            grouping: grouping,
            isDownloaded: {
                DownloadState.current(for: M4BImporter.fileURL(for: $0.fileName)) == .downloaded
            }
        )
    }

    var body: some View {
        presenters(shelf)
            .task { if store == nil { store = LibraryStore(context: context) } }
    }

    private var shelf: some View {
        ScrollView {
            if sections.allSatisfy(\.books.isEmpty) {
                Text("No books match this filter.")
                    .font(Typography.body(14.5)).foregroundStyle(Theme.text2)
                    .frame(maxWidth: .infinity).padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        if let title = section.title {
                            Text(title).eyebrowStyle().padding(.top, 24).padding(.bottom, 12)
                        }
                        if layout == .grid {
                            grid(section.books, width: gridWidth)
                        } else {
                            ForEach(section.books) { listRow($0) }
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.width
                } action: {
                    gridWidth = $0
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, Theme.botSafe + Theme.miniPlayerInset)
            }
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .navigationTitle("Your Library")
        .navigationBarTitleDisplayMode(.inline)
        .background(NavTitleFont())
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) { deleteButton }
            ToolbarItem(placement: .principal) { selectionTitle }
            ToolbarItem(placement: .topBarTrailing) { doneButton }
        } else {
            ToolbarItem(placement: .topBarTrailing) { optionsMenu }
        }
    }

    // MARK: Options menu
    /// One control for the whole page. Each knob — Filter, Sorting, View Options, and
    /// Grouping — nests in its own labeled submenu; Sorting holds the sort field and
    /// direction as two inline sections. A destructive Reset Options at the bottom clears
    /// everything back to defaults. The glyph tints accent while a non-`all` filter hides
    /// books, so a narrowed list is obvious at a glance.
    private var optionsMenu: some View {
        Menu {
            Menu("Filter", systemImage: "line.3.horizontal.decrease") {
                Picker("Filter", selection: $filter) {
                    ForEach(LibraryFilter.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
            }
            Menu("Sorting", systemImage: "arrow.up.arrow.down") {
                Picker("Sort By", selection: $sort) {
                    ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                Picker("Order", selection: $direction) {
                    ForEach(SortDirection.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
            }
            Menu("View Options", systemImage: "rectangle.grid.1x2") {
                Picker("Layout", selection: $layout) {
                    ForEach(LibraryLayout.allCases) { Text($0.label).tag($0) }
                }
            }
            Menu("Grouping", systemImage: "square.stack.3d.up") {
                Picker("Group by", selection: $grouping) {
                    ForEach(LibraryGrouping.allCases) { Text($0.label).tag($0) }
                }
            }
            Section {
                Button(role: .destructive) {
                    resetOptions()
                } label: {
                    Label("Reset Options", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            let active = filter != .all
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(active ? Theme.accent : Theme.text2)
        }
    }

    /// Restores all five view options to the defaults that reproduce the page's
    /// out-of-box arrangement (newest-first grid, unfiltered, ungrouped).
    private func resetOptions() {
        Haptics.tap()
        filter = .all
        sort = .dateAdded
        direction = .descending
        grouping = .none
        layout = .grid
    }

    // MARK: Selection toolbar
    private var selectionTitle: some View {
        Text("\(selection.count) Selected")
            .font(Typography.body(15, weight: .medium))
            .foregroundStyle(Theme.text)
    }

    private var doneButton: some View {
        Button {
            Haptics.tap()
            isSelecting = false
            selection.removeAll()
        } label: {
            Text("Done").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text2)
        }
    }

    private var deleteButton: some View {
        Button {
            Haptics.tap()
            pendingBatchDelete = true
        } label: {
            Text("Delete")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(selection.isEmpty ? Theme.text3 : .red)
        }
        .disabled(selection.isEmpty)
    }

    // MARK: Grid
    private func grid(_ books: [Book], width: CGFloat) -> some View {
        let cols = GridMath.columns(forWidth: width, targetCell: gridTargetCell, gutter: gridGutter)
        let size = GridMath.cellSize(forWidth: width, columns: cols, gutter: gridGutter)
        let columns = Array(repeating: GridItem(.fixed(size), spacing: gridGutter), count: cols)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: gridGutter) {
            if width > 0 {
                ForEach(books) { gridCell($0, size: size) }
            }
        }
    }

    private func gridCell(_ book: Book, size: CGFloat) -> some View {
        let isSelected = selection.contains(book.id)
        return Button {
            if isSelecting {
                toggleSelection(book)
            } else {
                Haptics.tap()
                onShowDetails(book)
            }
        } label: {
            BookGridCell(
                book: book,
                size: size,
                cloudState: syncMonitor.state(for: book.fileName),
                isSelecting: isSelecting,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isSelecting {
                BookActionsMenu(
                    book: book,
                    onPlay: {
                        Haptics.tap()
                        onPlay(book)
                    },
                    onShowDetails: { onShowDetails(book) },
                    onEdit: { pendingEdit = book },
                    onSelect: {
                        selection = [book.id]
                        isSelecting = true
                    },
                    onMarkFinished: { markFinished(book) },
                    onResetProgress: { pendingReset = book },
                    shareItem: DownloadState.canShare(for: book)
                        ? SharedAudiobook(book: book) : nil,
                    onRemoveDownload: DownloadState.canRemoveDownload(for: book)
                        ? { removeDownload(book) } : nil,
                    onDelete: { pendingDelete = book }
                )
            }
        }
    }

    // MARK: List
    private func listRow(_ book: Book) -> some View {
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

    // MARK: Actions
    private func toggleSelection(_ book: Book) {
        if selection.contains(book.id) {
            selection.remove(book.id)
        } else {
            selection.insert(book.id)
        }
        Haptics.tap()
    }

    private func deleteSelected() {
        let toDelete = books.filter { selection.contains($0.id) }
        for book in toDelete { engine.eject(book) }
        store?.delete(toDelete)
        selection.removeAll()
        isSelecting = false
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

    // MARK: Dialogs
    private func presenters(_ content: some View) -> some View {
        content
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
            .confirmationDialog("Delete selected books?", isPresented: $pendingBatchDelete) {
                Button("Delete", role: .destructive) { deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(DeleteCopy.multiple(syncEnabled: syncOn))
            }
            .sheet(item: $pendingEdit) { book in
                EditBookView(book: book)
            }
    }
}
