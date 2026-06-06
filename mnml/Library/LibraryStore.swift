//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData

/// Result of importing one file.
enum ImportOutcome { case imported, skippedDuplicate, failed }

/// Tally of a folder batch import.
struct ImportSummary {
    var imported = 0
    var skipped = 0
    var failed = 0

    /// The post-import alert this tally should produce. Pure (counts in →
    /// scenario out), so it's unit-testable without touching localization;
    /// `ImportNotice` renders the user-facing title and message.
    var notice: ImportNotice {
        switch (imported, skipped, failed) {
        case (0, 0, 0):
            return .nothingFound
        case (let added, 0, 0):
            return .added(added)
        case (0, let skipped, let failed):
            return .noneAdded(skipped: skipped, failed: failed)
        case (let added, let skipped, let failed):
            return .addedWithIssues(added: added, skipped: skipped, failed: failed)
        }
    }
}

/// What the post-import alert should say. The case captures the *scenario*
/// (decided purely from the import counts); `title` and `message` render the
/// localized copy. Splitting the two keeps the count → scenario logic testable
/// without depending on the current locale.
enum ImportNotice: Equatable {
    case nothingFound  // a picked folder held no audiobooks
    case added(Int)  // every file imported cleanly
    case addedWithIssues(added: Int, skipped: Int, failed: Int)  // some imported, some skipped/failed
    case noneAdded(skipped: Int, failed: Int)  // nothing new — all dupes/unreadable
    case alreadyInLibrary  // single picked file is a duplicate
    case cloudEmpty  // iCloud Import/ folder is empty

    /// Alert title, varying with the outcome so a "nothing found" result never
    /// reads under an "Import complete"-style header.
    var title: String {
        switch self {
        case .added, .addedWithIssues:
            return L.string("Import complete")
        case .noneAdded:
            return L.string("Nothing added")
        case .nothingFound, .cloudEmpty:
            return L.string("Nothing to import")
        case .alreadyInLibrary:
            return L.string("Already in your library")
        }
    }

    /// Alert body. Multi-count outcomes are built from per-clause, pluralized
    /// strings joined one-per-line so each line reads as a full sentence.
    var message: String {
        switch self {
        case .nothingFound:
            return L.string("No audiobooks were found in that folder.")
        case .added(let count):
            return Self.addedClause(count)
        case .addedWithIssues(let added, let skipped, let failed):
            return [
                Self.addedClause(added),
                Self.skippedClause(skipped),
                Self.failedClause(failed),
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
        case .noneAdded(let skipped, let failed):
            return [
                Self.skippedClause(skipped),
                Self.failedClause(failed),
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
        case .alreadyInLibrary:
            return L.string("That book is already in your library.")
        case .cloudEmpty:
            return L.string(
                "Nothing to import. Put audiobooks in the “Import” folder in your iCloud Drive (mnml), then tap Import from iCloud Drive again."
            )
        }
    }

    private static func addedClause(_ count: Int) -> String {
        L.string("Added \(count) audiobooks to your library.")
    }

    /// nil when the count is zero, so the clause drops out of the joined body.
    private static func skippedClause(_ count: Int) -> String? {
        count > 0 ? L.string("Skipped \(count) already in your library.") : nil
    }

    private static func failedClause(_ count: Int) -> String? {
        count > 0 ? L.string("\(count) files couldn't be read.") : nil
    }
}

/// Live state of an in-flight import, surfaced to the UI for a progress banner.
enum ImportProgress: Equatable {
    case idle
    case single  // one file, indeterminate
    case folder(completed: Int, total: Int)  // determinate

    var isActive: Bool { self != .idle }

    /// User-facing banner text shown while an import is in flight.
    var label: String {
        switch self {
        case .idle:
            return ""
        case .single:
            return "Importing…"
        case .folder(let completed, let total):
            return "Importing \(completed) of \(total)…"
        }
    }

    /// Progress-bar fill in 0...1; nil means indeterminate (spinner only).
    var fraction: Double? {
        switch self {
        case .idle, .single:
            return nil
        case .folder(let completed, let total):
            return total > 0 ? Double(completed) / Double(total) : nil
        }
    }
}

/// Owns library mutations against the SwiftData context. Views query Books via
/// @Query; this store handles add/delete and the import → Book assembly.
@Observable
final class LibraryStore {
    private let context: ModelContext
    var importError: String?  // error alert ("Couldn't add book")
    var importNotice: ImportNotice?  // informational alert (dup skipped, folder summary)
    var importProgress: ImportProgress = .idle
    var isImporting: Bool { importProgress.isActive }

    init(context: ModelContext) { self.context = context }

    @MainActor
    func importBook(from pickedURL: URL) async -> ImportOutcome {
        importProgress = .single
        defer { importProgress = .idle }
        do {
            // Parse from the source first so a duplicate is caught before we copy the
            // (potentially huge) file into Books/.
            let metadata = try await M4BImporter.inspect(pickedURL, accessSecurityScope: true)
            let title = resolvedTitle(metadata, fallback: pickedURL)
            let author = metadata.author ?? ""
            if DuplicateMatcher.isDuplicate(
                title: title, author: author,
                duration: metadata.duration, against: existingFingerprints())
            {
                return .skippedDuplicate
            }
            let fileName = try await M4BImporter.place(
                copying: pickedURL, accessSecurityScope: true)
            insertBook(
                fileName: fileName, title: title,
                originalExtension: pickedURL.pathExtension.lowercased(), metadata: metadata)
            return .imported
        } catch M4BImporter.ImportError.invalidMedia {
            importError = L.string(
                "That file isn't a playable audiobook. Try an .m4b or .m4a file.")
            return .failed
        } catch {
            importError = L.string("Couldn't import that file.")
            return .failed
        }
    }

    /// Picks a folder, scans ≤2 levels deep for `.m4b` files, imports each.
    /// Returns nil if the folder couldn't be accessed (an error is set);
    /// otherwise a tally. Per-file failures are counted, never thrown.
    @MainActor
    func importFolder(from folderURL: URL) async -> ImportSummary? {
        defer { importProgress = .idle }

        let scoped = folderURL.startAccessingSecurityScopedResource()
        defer { if scoped { folderURL.stopAccessingSecurityScopedResource() } }
        guard scoped else {
            importError = "Couldn't open that folder."
            return nil
        }

        let files = FolderScanner.findM4Bs(in: folderURL)
        // Nothing to import: return the empty tally without flashing a "0 of 0" banner.
        guard !files.isEmpty else { return ImportSummary() }

        // Folder children belong to the user's picked folder — we only copy the ones
        // we keep, so there is nothing to clean up on a skip or failure.
        return await runBatch(
            files,
            inspect: { try await M4BImporter.inspect($0, accessSecurityScope: false) },
            place: { try await M4BImporter.place(copying: $0, accessSecurityScope: false) }
        )
    }

    /// Scans `Inbox/` for top-level `.m4b` files the user dropped in and imports
    /// each by MOVING it into `Books/` (see `M4BImporter.place(movingInbox:)`).
    /// No-ops while another import is already running (a picker/folder import in
    /// flight); the next foreground scan will pick the inbox up. Returns nil when
    /// it no-ops, otherwise a tally. Reuses the same progress banner, dedup, and
    /// summary as folder import. A skipped (duplicate) or failed (corrupt) file is
    /// removed from Inbox so it isn't re-scanned on every launch.
    @MainActor
    func importInbox() async -> ImportSummary? {
        guard !isImporting else { return nil }

        let files = FolderScanner.findTopLevelM4Bs(in: M4BImporter.inboxDirectory)
        // Nothing dropped in: return the empty tally without flashing a banner.
        guard !files.isEmpty else { return ImportSummary() }

        defer { importProgress = .idle }
        return await runBatch(
            files,
            inspect: { try await M4BImporter.inspect($0, accessSecurityScope: false) },
            place: { try await M4BImporter.place(movingInbox: $0) },
            cleanupSkipped: { try? FileManager.default.removeItem(at: $0) }
        )
    }

    /// Imports audiobooks the user dropped into the iCloud `Import/` folder, MOVING each
    /// into `Books/` (no duplicate left behind). Addition-only with the normal dedup —
    /// nothing is ever deleted from the library. Reuses the shared `runBatch` driver, so it
    /// inherits the same progress banner, dedup-before-copy, and summary as folder/inbox
    /// import.
    ///
    /// Cloud specifics: the `inspect` closure materializes the file first (cloud placeholders
    /// aren't readable until downloaded); new books are moved in via `place(movingCloud:)`;
    /// and `cleanupSkipped` removes a skipped/failed source from `Import/` under file
    /// coordination so the removal propagates. A file that can't be downloaded is left in
    /// `Import/` as a placeholder to retry — `coordinatedRemove` no-ops when the real file
    /// is absent.
    ///
    /// Sets `importError`/`importNotice` itself for the iCloud-unavailable and empty-folder
    /// cases (so the caller doesn't have to disambiguate a bare `nil`); returns `nil` only on
    /// the already-importing no-op, and an `ImportSummary` when files were processed.
    @MainActor
    func importCloudDrive() async -> ImportSummary? {
        guard !isImporting else { return nil }

        // Resolve + scan off the main thread (container provisioning can block).
        let dir =
            await Task.detached(priority: .userInitiated) {
                M4BImporter.cloudImportDirectory
            }
            .value
        guard let dir else {
            importError = L.string("Sign in to iCloud to import from iCloud Drive.")
            return ImportSummary()
        }

        let files =
            await Task.detached(priority: .userInitiated) {
                FolderScanner.findTopLevelM4BsIncludingCloud(in: dir)
            }
            .value
        guard !files.isEmpty else {
            importNotice = .cloudEmpty
            return ImportSummary()
        }

        defer { importProgress = .idle }
        return await runBatch(
            files,
            inspect: { url in
                try await FileDownloader.ensureDownloaded(at: url)
                return try await M4BImporter.inspect(url, accessSecurityScope: false)
            },
            place: { try await M4BImporter.place(movingCloud: $0) },
            cleanupSkipped: { url in _ = self.coordinatedRemove(url) }
        )
    }

    /// Shared driver for folder/inbox batch imports. Per file: parse metadata from
    /// the source (cheap), skip it if it duplicates the library or a book added
    /// earlier in *this* batch, and only then `place` it on disk — so a duplicate is
    /// never copied. `cleanupSkipped`, when set, runs on the source URL of every
    /// skipped or failed file (used to empty the Inbox); it's nil for picked folders,
    /// whose originals must be left untouched.
    @MainActor
    private func runBatch(
        _ files: [URL],
        inspect: (URL) async throws -> ExtractedMetadata,
        place: (URL) async throws -> String,
        cleanupSkipped: ((URL) -> Void)? = nil
    ) async -> ImportSummary {
        // Snapshot the library once, then grow it as we add books — so a folder that
        // holds the same title twice still imports it once, without re-querying
        // SwiftData for every file (the old per-file fetch was the batch's hot path).
        var fingerprints = existingFingerprints()
        importProgress = .folder(completed: 0, total: files.count)

        var summary = ImportSummary()
        for url in files {
            do {
                let metadata = try await inspect(url)
                let title = resolvedTitle(metadata, fallback: url)
                let author = metadata.author ?? ""
                if DuplicateMatcher.isDuplicate(
                    title: title, author: author,
                    duration: metadata.duration, against: fingerprints)
                {
                    cleanupSkipped?(url)
                    summary.skipped += 1
                } else {
                    let fileName = try await place(url)
                    insertBook(
                        fileName: fileName, title: title,
                        originalExtension: url.pathExtension.lowercased(), metadata: metadata)
                    fingerprints.append((title: title, author: author, duration: metadata.duration))
                    summary.imported += 1
                }
            } catch {
                cleanupSkipped?(url)
                summary.failed += 1
            }
            let done = summary.imported + summary.skipped + summary.failed
            importProgress = .folder(completed: done, total: files.count)
        }
        return summary
    }

    /// Title to show for an import: the embedded title, or the file name when the
    /// file carries none.
    private func resolvedTitle(_ metadata: ExtractedMetadata, fallback: URL) -> String {
        metadata.title?.isEmpty == false
            ? metadata.title!
            : fallback.deletingPathExtension().lastPathComponent
    }

    /// The current library as dedup fingerprints (title/author/duration).
    private func existingFingerprints() -> [(title: String, author: String, duration: Double)] {
        (try? context.fetch(FetchDescriptor<Book>()))?
            .map {
                (title: $0.title, author: $0.author, duration: $0.durationSeconds)
            } ?? []
    }

    /// Builds a Book (with chapters) from extracted metadata and saves it.
    @MainActor
    private func insertBook(
        fileName: String, title: String, originalExtension: String, metadata: ExtractedMetadata
    ) {
        let book = Book(
            title: title,
            author: metadata.author ?? "",
            narrator: nil,
            fileName: fileName,
            artworkData: metadata.artworkData,
            tint: CoverTint.assign(for: title),
            durationSeconds: metadata.duration,
            dateAdded: .now,
            originalExtension: originalExtension
        )
        for (i, ch) in metadata.chapters.enumerated() {
            let chapter = Chapter(
                title: ch.title, startTime: ch.startTime,
                duration: ch.duration, order: i)
            chapter.book = book
            book.chapters = (book.chapters ?? []) + [chapter]
        }
        context.insert(book)
        try? context.save()
    }

    @MainActor
    func delete(_ book: Book) {
        // Remove the file (coordinated, so it propagates through iCloud) FIRST, and only
        // drop the record if the file is actually gone — otherwise a failed/locked removal
        // would orphan the file with no record left to retry it.
        guard coordinatedRemove(M4BImporter.fileURL(for: book.fileName)) else { return }
        context.delete(book)
        try? context.save()
    }

    /// Batch variant of `delete(_:)`. Removes each book's file and only then its record,
    /// saving once after the whole batch (one disk write instead of N).
    @MainActor
    func delete(_ books: [Book]) {
        var removedAny = false
        for book in books where coordinatedRemove(M4BImporter.fileURL(for: book.fileName)) {
            context.delete(book)
            removedAny = true
        }
        if removedAny { try? context.save() }
    }

    /// Evicts this device's downloaded copy without deleting the record or the
    /// iCloud original. The book stays in the library and re-downloads on next play.
    /// Only meaningful when sync is on and the file is currently downloaded — the
    /// caller gates this with `DownloadState.canRemoveDownload`.
    @MainActor
    func removeDownload(_ book: Book) {
        // Fire-and-forget off the main thread; the cloud-only badge updates on its own
        // via the metadata query once the local copy is gone.
        let url = M4BImporter.fileURL(for: book.fileName)
        Task { try? await FileDownloader.evict(at: url) }
    }

    /// Bulk twin of `removeDownload`: evicts every book's local copy in one pass,
    /// leaving the iCloud originals (so each book re-downloads on next play). Backs
    /// Settings' "Free Up Space". Evicting a file that isn't downloaded throws, so
    /// each eviction is best-effort. Awaitable so the caller can re-measure storage
    /// once the disk has actually been reclaimed.
    @MainActor
    func removeAllDownloads(_ books: [Book]) async {
        for book in books {
            let url = M4BImporter.fileURL(for: book.fileName)
            try? await FileDownloader.evict(at: url)
        }
        sweepOrphans()
        await sweepCloudImportLeftovers()
    }

    /// Best-effort companion to "Free Up Space": evicts any downloaded files still staged
    /// in the iCloud `Import/` folder back to iCloud placeholders, reclaiming their on-disk
    /// bytes. Safe because `Import/` lives in the iCloud container, so an iCloud copy always
    /// remains. No-op when iCloud is unavailable. Listing + eviction run off the main thread.
    @MainActor
    private func sweepCloudImportLeftovers() async {
        let urls =
            await Task.detached(priority: .utility) { () -> [URL] in
                guard let dir = M4BImporter.cloudImportDirectory else { return [] }
                let entries =
                    (try? FileManager.default.contentsOfDirectory(
                        at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: []))
                    ?? []
                return entries.filter {
                    (try? $0.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
                }
            }
            .value
        for url in urls {
            // Evicting a file that isn't downloaded (already a placeholder) throws — ignore.
            try? await FileDownloader.evict(at: url)
        }
    }

    /// Deletes files in `Books/` that no record claims — leftovers from interrupted
    /// iCloud moves or merged-record dedup, plus anything dropped into the app's iCloud
    /// Drive folder by hand. Without this they'd keep inflating the storage figures and
    /// stop "Free Up Space" from reaching zero, since `removeAllDownloads` only evicts
    /// record-backed files. Runs after eviction, so a book we just evicted reads as its
    /// own placeholder (kept) rather than an orphan. Coordinated, so iCloud mirrors each
    /// removal to every device — junk shouldn't linger anywhere.
    ///
    /// Skipped mid-import: `place` copies a file into `Books/` *before* its record is
    /// saved, so a freshly placed import briefly looks exactly like an orphan, and
    /// deleting it would lose the import — the data-loss class this branch hardens against.
    @MainActor
    private func sweepOrphans() {
        guard !isImporting else { return }
        let dir = M4BImporter.booksDirectory
        guard
            let urls = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isRegularFileKey])
        else { return }
        // Only regular files, matching exactly what StorageUsage.measure() tallies — so
        // a stray directory is never removed and the swept figure can actually hit zero.
        let diskNames = urls.compactMap { url -> String? in
            (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
                ? url.lastPathComponent : nil
        }
        let claimed = Set((try? context.fetch(FetchDescriptor<Book>()))?.map(\.fileName) ?? [])
        for name in OrphanScanner.orphans(onDisk: diskNames, claimedBy: claimed) {
            coordinatedRemove(dir.appendingPathComponent(name))
        }
    }

    /// Collapses books that are the same audiobook (same title/author/duration per
    /// `DuplicateMatcher`) but exist as separate records — e.g. the same book imported
    /// on two devices while offline, then merged by CloudKit (which forbids the unique
    /// constraint that used to prevent this locally). Keeps the furthest-progressed copy
    /// and removes the redundant record and its local file. Best-effort; safe to re-run.
    @MainActor
    func reconcileDuplicates() {
        guard let all = try? context.fetch(FetchDescriptor<Book>()), all.count > 1 else { return }
        var groups: [[Book]] = []
        for book in all {
            if let idx = groups.firstIndex(where: { group in
                guard let rep = group.first else { return false }
                return DuplicateMatcher.isDuplicate(
                    title: book.title, author: book.author, duration: book.durationSeconds,
                    against: [(title: rep.title, author: rep.author, duration: rep.durationSeconds)]
                )
            }) {
                groups[idx].append(book)
            } else {
                groups.append([book])
            }
        }
        var changed = false
        for group in groups where group.count > 1 {
            guard let keep = LibraryStore.survivor(of: group) else { continue }
            for dupe in group where dupe.id != keep.id {
                coordinatedRemove(M4BImporter.fileURL(for: dupe.fileName))
                context.delete(dupe)
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Of a group judged to be the same audiobook, the record to KEEP: the furthest-
    /// progressed copy wins (never lose the user's position); ties break to the earliest
    /// `dateAdded` for stability. Pure, so it is unit-testable without a context.
    static func survivor(of dupes: [Book]) -> Book? {
        dupes.max { a, b in
            a.progressSeconds != b.progressSeconds
                ? a.progressSeconds < b.progressSeconds
                : a.dateAdded > b.dateAdded
        }
    }

    /// Deletes a (possibly ubiquitous) file under file coordination so iCloud sees the
    /// removal and mirrors it to other devices. Returns `true` when the file is gone
    /// afterward (removed now, or never existed); `false` if it is still on disk, so the
    /// caller can keep the record rather than orphan the file.
    @discardableResult
    private func coordinatedRemove(_ url: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return true }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { u in
            try? fm.removeItem(at: u)
        }
        return !fm.fileExists(atPath: url.path)
    }
}
