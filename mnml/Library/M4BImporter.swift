//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Copies a picked M4B into Documents/Books/ and extracts its metadata.
/// Returns the data needed to build a Book; UI-free.
///
/// `nonisolated` opts the whole type out of the project's default `MainActor`
/// isolation (SWIFT_DEFAULT_ACTOR_ISOLATION), and the import entry points are
/// `@concurrent` so the blocking file copy + AVFoundation parsing run on the
/// global executor instead of freezing the UI during a large import.
nonisolated enum M4BImporter {
    enum ImportError: Error { case cannotAccess, copyFailed(Error), invalidMedia }

    /// The active `Books/` directory, resolved once at launch by
    /// `LibraryFileSync.configureAtLaunch()`. Written exactly once early in launch
    /// before any concurrent import runs, hence `nonisolated(unsafe)`. Until it's
    /// set (or when sync is off) this falls back to local `Documents/Books`.
    nonisolated(unsafe) static var resolvedBooksDirectory: URL?

    private static var localBooksDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Books", isDirectory: true)
    }

    static var booksDirectory: URL {
        let dir = resolvedBooksDirectory ?? localBooksDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Pins the active `Books/` directory for the rest of the process. Called once
    /// at launch after the iCloud container is resolved.
    static func useBooksDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        resolvedBooksDirectory = url
    }

    static var inboxDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// The iCloud Drive "Import" drop folder: `…/Documents/Import/`, a sibling of the
    /// container's `Books/`. Nil when iCloud is unavailable (no account / the container
    /// can't be provisioned). Created if missing.
    ///
    /// IMPORTANT: call OFF the main thread — `UbiquityContainer.documentsURL()` can block
    /// while the container is provisioned on first access.
    static var cloudImportDirectory: URL? {
        guard let docs = UbiquityContainer.documentsURL() else { return nil }
        let dir = docs.appendingPathComponent("Import", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(for fileName: String) -> URL {
        let resolved = booksDirectory.appendingPathComponent(fileName)
        // When the active directory is the iCloud container but an earlier launch failed
        // to migrate this file, the real copy may still be in local Documents/Books. Fall
        // back to it so the book stays playable instead of resolving to a missing path.
        // (A not-yet-downloaded iCloud placeholder still exists at `resolved`, so this only
        // triggers when the file is genuinely absent from the container.)
        if resolvedBooksDirectory != nil,
            !FileManager.default.fileExists(atPath: resolved.path)
        {
            let local = localBooksDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: local.path) { return local }
        }
        return resolved
    }

    /// Reads and validates an audiobook's metadata straight from its source URL,
    /// WITHOUT copying it into `Books/`. The caller dedups on this metadata first
    /// and only then `place`s the file — so a duplicate never pays for a full copy.
    ///
    /// `accessSecurityScope` is true for a file picked directly via `.fileImporter`
    /// (its URL is security-scoped); false for a folder child whose parent already
    /// holds the scope, or for a file already inside the app sandbox (the Inbox).
    @concurrent
    static func inspect(_ url: URL, accessSecurityScope: Bool) async throws -> ExtractedMetadata {
        let scoped = accessSecurityScope && url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if accessSecurityScope && !scoped { throw ImportError.cannotAccess }

        let metadata = try await MetadataExtractor.extract(from: url)
        // A file can still be unreadable as media (corrupt, DRM, or not really
        // audio). AVFoundation reports no usable duration in that case → reject it.
        guard metadata.duration.isFinite, metadata.duration > 0 else {
            throw ImportError.invalidMedia
        }
        return metadata
    }

    /// Copies a source file into `Books/`, returning its new file name. Call only
    /// after `inspect` has confirmed the book is new — duplicates never reach disk.
    /// `accessSecurityScope` matches `inspect`'s rule.
    @concurrent
    static func place(copying source: URL, accessSecurityScope: Bool) async throws -> String {
        let scoped = accessSecurityScope && source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        if accessSecurityScope && !scoped { throw ImportError.cannotAccess }

        let fileName = "\(UUID().uuidString).m4b"
        do {
            try FileManager.default.copyItem(at: source, to: fileURL(for: fileName))
        } catch {
            throw ImportError.copyFailed(error)
        }
        return fileName
    }

    /// Moves an Inbox file into `Books/`, returning its new file name (Inbox empties
    /// as it goes — no double storage). No security scope: both dirs are in the app
    /// sandbox. Call only after `inspect` confirms the book is new.
    @concurrent
    static func place(movingInbox inboxURL: URL) async throws -> String {
        let fileName = "\(UUID().uuidString).m4b"
        do {
            try FileManager.default.moveItem(at: inboxURL, to: fileURL(for: fileName))
        } catch {
            throw ImportError.copyFailed(error)
        }
        return fileName
    }

    /// Moves a (possibly ubiquitous) file under file coordination so iCloud sees the
    /// removal from the source and mirrors it to other devices. Used to consume a file
    /// out of the iCloud `Import/` folder into `Books/`.
    private static func coordinatedMove(from src: URL, to dest: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordError: NSError?
        var moveError: Error?
        coordinator.coordinate(
            writingItemAt: src, options: .forMoving,
            writingItemAt: dest, options: [], error: &coordError
        ) { s, d in
            do { try FileManager.default.moveItem(at: s, to: d) } catch { moveError = error }
        }
        if let coordError { throw ImportError.copyFailed(coordError) }
        if let moveError { throw ImportError.copyFailed(moveError) }
    }

    /// Moves a file out of the iCloud `Import/` folder into `Books/`, returning its new
    /// file name (the source leaves `Import/` — no duplicate). The move is file-coordinated
    /// so iCloud mirrors the removal to other devices. Call only after `inspect` confirms
    /// the book is new (inspect also materializes the file, so it is local by now).
    @concurrent
    static func place(movingCloud sourceURL: URL) async throws -> String {
        let fileName = "\(UUID().uuidString).m4b"
        try coordinatedMove(from: sourceURL, to: fileURL(for: fileName))
        return fileName
    }
}
