//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerEngine.self) private var engine
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var store: LibraryStore?
    @State private var showImporter = false
    @State private var importMode: ImportMode = .file
    @State private var pendingDelete: Book?
    @State private var pendingReset: Book?
    @State private var pendingEdit: Book?
    @State private var gridWidth: CGFloat = 0
    let onPlay: (Book) -> Void
    let onOpenPlayer: () -> Void
    let onShowDetails: (Book) -> Void
    let onShowContinueListening: () -> Void
    let onShowLibrary: () -> Void

    // Continue Listening is a capped quick-resume shortcut: the 3 most-recently-played
    // in-progress books. Started books also appear in the grid below (intentional).
    private var continuing: [Book] {
        Array(
            books.filter { $0.progressSeconds > 0 }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
                .prefix(3))
    }
    // Home shows at most the 10 most-recent books; the rest live on the full library page.
    private var libraryPreview: [Book] { Array(books.prefix(6)) }

    /// Total length of every book on the shelf — derived, not stored.
    private var shelfSeconds: Double { books.reduce(0) { $0 + $1.durationSeconds } }

    var body: some View {
        presenters(shelf)
            // Pinned just under the nav bar so the user always sees import progress no
            // matter how far they've scrolled. Overlay (not in-scroll) keeps it stationary.
            .overlay(alignment: .top) {
                if let store, store.importProgress.isActive {
                    ImportBanner(progress: store.importProgress)
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: store?.importProgress)
            .task {
                if store == nil { store = LibraryStore(context: context) }
                await scanInbox()  // also lazily creates Inbox/ so it appears in the Files app
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await scanInbox() } }
            }
    }

    /// The scrollable shelf and its nav-bar toolbars. Split out from `body`'s importer/
    /// alert/dialog modifiers so neither expression overflows the SwiftUI type-checker.
    private var shelf: some View {
        ScrollView {
            if books.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        // The wordmark + add button live in the nav bar (pinned), not the scroll
        // content. The empty state is a hero layout with no top bar.
        .toolbar(books.isEmpty ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            if !books.isEmpty {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { wordmark }
                        .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) { trailingActions }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { wordmark }
                    ToolbarItem(placement: .topBarTrailing) { trailingActions }
                }
            }
        }
    }

    /// Applies the file importers, import alerts, and the delete/reset confirmation
    /// dialogs to `content`. Kept separate from `shelf` so each modifier chain stays
    /// small enough for the SwiftUI type-checker.
    private func presenters(_ content: some View) -> some View {
        content
            // A single importer driven by `importMode`. SwiftUI only honors one
            // `.fileImporter` per view — stacking two means the later one wins and the
            // other silently does nothing, so file *and* folder import share one here.
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: importMode == .folder ? [.folder] : fileImportTypes,
                allowsMultipleSelection: false
            ) { result in
                switch importMode {
                case .file: handleFileImport(result)
                case .folder: handleFolderImport(result)
                }
            }
            .alert(
                "Couldn't add book",
                isPresented: Binding(
                    get: { store?.importError != nil },
                    set: { if !$0 { store?.importError = nil } }
                ), presenting: store?.importError
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: {
                Text($0)
            }
            .alert(
                store?.importNotice?.title ?? "",
                isPresented: Binding(
                    get: { store?.importNotice != nil },
                    set: { if !$0 { store?.importNotice = nil } }
                ), presenting: store?.importNotice
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: {
                Text($0.message)
            }
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
        // Keep the book in the mini player so it can be resumed — just tear down the
        // open file (no-op unless it's the loaded book) before evicting it.
        engine.releaseDownload(book)
        store?.removeDownload(book)
    }

    /// True when iCloud Sync is on — delete then removes the book from every device.
    private var syncOn: Bool { CloudSyncPreference().isEnabled }

    /// Which kind of import the shared `.fileImporter` is presenting.
    private enum ImportMode { case file, folder }

    /// Content types the file picker accepts (`.m4b` + `.m4a`, from the scanner's
    /// shared list). Falls back to all audio if the system can't resolve any of
    /// them, so the picker always has a presentable type (an empty list would
    /// refuse to open).
    private var fileImportTypes: [UTType] {
        let types = FolderScanner.audiobookExtensions.compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.audio] : types
    }

    /// Wordmark + accent dot — the nav bar's leading "title".
    private var wordmark: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("mnml").font(Typography.wordmark).tracking(-0.7).foregroundStyle(Theme.text)
            Circle().fill(Theme.accent).frame(width: 4, height: 4).offset(y: -3)
        }
        .fixedSize()
    }

    private var addButton: some View {
        // A Menu presents on tap with no action closure, so the previous tap
        // haptic is dropped — iOS opens the menu directly.
        // Disabled while an import is running so the user can't start a second one on
        // top of the first — matches the pinned banner that signals "busy".
        Menu {
            importMenuItems
        } label: {
            Image(systemName: "plus").font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.text2)
        }
        .disabled(store?.isImporting == true)
    }

    /// Shared menu actions for both the toolbar button and the empty-state button.
    /// "Import from iCloud Drive" + its tip appear only when Sync is on (the Import/
    /// folder is a sibling of the iCloud Books/ store, which only exists when syncing).
    @ViewBuilder private var importMenuItems: some View {
        Section {
            Button {
                importMode = .file
                showImporter = true
            } label: {
                Label("Select File", systemImage: "doc")
            }
            Button {
                importMode = .folder
                showImporter = true
            } label: {
                Label("Select from Folder", systemImage: "folder")
            }
            if syncOn {
                Button {
                    Task { await runCloudImport() }
                } label: {
                    Label("Import from iCloud Drive", systemImage: "icloud")
                }
            }
        } footer: {
            if syncOn {
                Text(
                    "Drop audiobooks in the “Import” folder in your iCloud Drive (mnml), then choose Import from iCloud Drive."
                )
            }
        }
    }

    /// The add button, alone in the trailing nav-bar slot. (Settings moved to its
    /// own tab, so the gearshape no longer lives here.)
    private var trailingActions: some View {
        addButton
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !continuing.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text("Continue Listening").eyebrowStyle()
                    Spacer()
                    Button {
                        onShowContinueListening()
                    } label: {
                        Text("See more")
                            .font(Typography.body(12))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.bottom, 6)
                ForEach(continuing) { book in
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
                Rectangle().fill(Theme.hairline(scheme)).frame(height: 0.5)
                    .padding(.vertical, 32)
            }
            StatsRow(shelfSeconds: shelfSeconds)
            Rectangle().fill(Theme.hairline(scheme)).frame(height: 0.5)
                .padding(.vertical, 32)
            HStack(alignment: .firstTextBaseline) {
                Text("Your Library").eyebrowStyle()
                Spacer()
                Button {
                    onShowLibrary()
                } label: {
                    Text("See more")
                        .font(Typography.body(12))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.bottom, 16)
            grid(width: gridWidth)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.width
                } action: {
                    gridWidth = $0
                }
            Button {
                Haptics.tap()
                onShowLibrary()
            } label: {
                HStack(spacing: 6) {
                    Text("See full library")
                        .font(Typography.body(15, weight: .medium)).tracking(-0.15)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.hairline(scheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, Theme.botSafe + Theme.miniPlayerInset)
    }

    // Library grid: ~165pt target cell, 16pt gutters → 2 columns on iPhone, more on iPad.
    private let gridTargetCell: CGFloat = 165
    private let gridGutter: CGFloat = 16

    private func grid(width: CGFloat) -> some View {
        let cols = GridMath.columns(forWidth: width, targetCell: gridTargetCell, gutter: gridGutter)
        let size = GridMath.cellSize(forWidth: width, columns: cols, gutter: gridGutter)
        let columns = Array(repeating: GridItem(.fixed(size), spacing: gridGutter), count: cols)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: gridGutter) {
            // Skip cells until the first geometry pass reports a real width; otherwise
            // cellSize is 0 and covers render at zero size (a one-frame flicker). The
            // empty LazyVGrid still spans the full width, so .onGeometryChange fires and
            // the real layout lands on the next pass.
            if width > 0 {
                ForEach(libraryPreview) { gridCell($0, size: size) }
            }
        }
    }

    private func gridCell(_ book: Book, size: CGFloat) -> some View {
        Button {
            Haptics.tap()
            onShowDetails(book)
        } label: {
            BookGridCell(
                book: book,
                size: size,
                cloudState: syncMonitor.state(for: book.fileName)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            BookActionsMenu(
                book: book,
                onPlay: {
                    Haptics.tap()
                    onPlay(book)
                },
                onShowDetails: { onShowDetails(book) },
                onEdit: { pendingEdit = book },
                onMarkFinished: { markFinished(book) },
                onResetProgress: { pendingReset = book },
                shareItem: DownloadState.canShare(for: book) ? SharedAudiobook(book: book) : nil,
                onRemoveDownload: DownloadState.canRemoveDownload(for: book)
                    ? { removeDownload(book) } : nil,
                onDelete: { pendingDelete = book }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 11) {
                Text("mnml").font(Typography.display(44)).tracking(-1.76)
                    .foregroundStyle(Theme.text)
                Circle().fill(Theme.accent).frame(width: 9, height: 9).offset(y: -7)
            }

            Text("It's quiet in here.")
                .font(Typography.display(21)).tracking(-0.63).foregroundStyle(Theme.text)
                .padding(.top, 34)

            Text(
                "Not a single audiobook on the shelf — just you and a faint echo. Import one and press play."
            )
            .font(Typography.body(14.5)).foregroundStyle(Theme.text2)
            .multilineTextAlignment(.center).lineSpacing(4)
            .frame(maxWidth: 252)
            .padding(.top, 10)

            Menu {
                importMenuItems
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 17, weight: .medium))
                    Text("Import").font(Typography.body(15, weight: .medium)).tracking(-0.15)
                }
                .foregroundStyle(.white)
                .frame(height: 48).padding(.horizontal, 22)
                .background(
                    Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store?.isImporting == true)
            .padding(.top, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .containerRelativeFrame(.vertical, alignment: .center)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            store?.importError = L.string("Couldn't open that file.")
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                let outcome = await store?.importBook(from: url)
                if outcome == .skippedDuplicate {
                    store?.importNotice = .alreadyInLibrary
                }
            }
        }
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            store?.importError = "Couldn't open that folder."
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                if let summary = await store?.importFolder(from: url) {
                    store?.importNotice = summary.notice
                }
            }
        }
    }

    /// Runs the inbox auto-import and shows the summary notice only when files
    /// were actually processed (so a normal empty-inbox launch stays silent).
    private func scanInbox() async {
        guard let store else { return }
        if let summary = await store.importInbox(),
            summary.imported + summary.skipped + summary.failed > 0
        {
            store.importNotice = summary.notice
        }
    }

    /// Runs the manual iCloud `Import/` import and shows the summary notice only when
    /// files were processed. The store sets its own notice for the empty/unavailable
    /// cases, so this leaves those alone.
    private func runCloudImport() async {
        guard let store else { return }
        if let summary = await store.importCloudDrive(),
            summary.imported + summary.skipped + summary.failed > 0
        {
            store.importNotice = summary.notice
        }
    }
}

/// Three lifetime/derived stats in the eyebrow visual language, shown below Continue
/// Listening. "Listened" and "Finished" are lifetime tallies from ListeningStats;
/// "On Your Shelf" is derived live from the library (passed in as `shelfSeconds`).
///
/// Its OWN `View` struct on purpose: the player ticks `stats.totalSecondsListened` ~4×/sec
/// during playback, so reading it here scopes that invalidation to this small row. Inlined
/// as a computed property of `LibraryView`, the read was attributed to `LibraryView.body`,
/// re-rendering the whole screen every tick — which flickered any open Menu (the ⋯ row
/// actions and the toolbar import +) for as long as audio was playing.
private struct StatsRow: View {
    @Environment(ListeningStats.self) private var stats
    let shelfSeconds: Double

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            statColumn("Listened", TimeFormat.fmtStat(stats.totalSecondsListened))
            statColumn("Finished", booksFinishedLabel)
            statColumn("On Your Shelf", TimeFormat.fmtStat(shelfSeconds))
        }
    }

    private var booksFinishedLabel: String {
        let n = stats.booksFinished
        return "\(n) book\(n == 1 ? "" : "s")"
    }

    private func statColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrowStyle()
            Text(value)
                .font(Typography.display(18, weight: .medium))
                .foregroundStyle(Theme.text)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 2px rounded progress bar, accent fill on track.
struct ProgressBar: View {
    let fraction: Double
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track(scheme))
                Capsule().fill(Theme.accent).frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 2)
    }
}
