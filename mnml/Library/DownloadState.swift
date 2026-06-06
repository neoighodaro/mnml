//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation

/// Whether a book's file is available on this device. `.downloading` is a transient
/// state the player sets while it awaits a download; the system status only ever
/// distinguishes downloaded vs not.
enum DownloadState: Equatable {
    case downloaded
    case downloading
    case notDownloaded

    /// Maps the system's ubiquitous download status. Both `.current` (up to date)
    /// and `.downloaded` (present, maybe stale) mean a local copy exists.
    static func from(_ status: URLUbiquitousItemDownloadingStatus?) -> DownloadState {
        switch status {
        case .some(.current), .some(.downloaded): return .downloaded
        default: return .notDownloaded
        }
    }

    /// The file's current state. A non-ubiquitous file (local-only mode, or never
    /// uploaded) counts as `.downloaded` only when it actually exists on disk — a
    /// missing path (orphaned record, failed migration) is `.notDownloaded`, so the
    /// player surfaces a download/error path instead of handing a dead URL to AVPlayer.
    static func current(for url: URL) -> DownloadState {
        let values = try? url.resourceValues(
            forKeys: [.ubiquitousItemDownloadingStatusKey, .isUbiquitousItemKey])
        if values?.isUbiquitousItem != true {
            return FileManager.default.fileExists(atPath: url.path) ? .downloaded : .notDownloaded
        }
        return from(values?.ubiquitousItemDownloadingStatus)
    }

    /// "Remove Download" is offered only when sync is on AND a local copy exists —
    /// in local-only mode evicting would destroy the sole copy (that's Delete instead).
    static func canRemoveDownload(syncEnabled: Bool, state: DownloadState) -> Bool {
        syncEnabled && state == .downloaded
    }

    /// Convenience for the common call site: resolves the sync preference and the
    /// book's on-disk state, so the library/detail views don't each re-wire the same
    /// `CloudSyncPreference` + `current(for:)` lookup.
    static func canRemoveDownload(for book: Book) -> Bool {
        canRemoveDownload(
            syncEnabled: CloudSyncPreference().isEnabled,
            state: current(for: M4BImporter.fileURL(for: book.fileName)))
    }

    /// Share is offered whenever a local copy of the file exists — always true in
    /// local-only mode, and true in sync mode once the book has been downloaded.
    /// Cloud-only books resolve to `.notDownloaded` and so hide the Share action.
    static func canShare(for book: Book) -> Bool {
        current(for: M4BImporter.fileURL(for: book.fileName)) == .downloaded
    }
}
