//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// A book file's iCloud transfer state on this device, surfaced by the library badge.
/// `.synced` is the steady state (present locally and fully uploaded) and shows no
/// chrome; the other cases each get a badge so the user can see what iCloud is doing:
///   - `.uploading`   — local file going up to iCloud (just turned sync on, etc.)
///   - `.downloading` — pulling a cloud-only file back down (e.g. after tapping Play)
///   - `.cloudOnly`   — in iCloud but NOT on this device; tap Play to download
///
/// `fraction` is 0...1, or `nil` when the system hasn't reported a percentage yet
/// (show an indeterminate badge).
enum BookCloudState: Equatable {
    case synced
    case uploading(fraction: Double?)
    case downloading(fraction: Double?)
    case cloudOnly
    /// Sync is intended but no usable iCloud account/container is present, so we
    /// can't claim the file is uploaded. Surfaced as a distinct "unavailable" badge
    /// instead of a false `.synced`.
    case unavailable
}

/// Watches the app's iCloud Drive container and reports each book file's transfer
/// state, so the library can badge books that are uploading, downloading, or live
/// only in iCloud (not yet on this device) — answering both "is my book actually
/// syncing up?" and "which books aren't downloaded here?".
///
/// Backed by `NSMetadataQuery`, the only API that reports live transfer progress for
/// ubiquitous items (`URLResourceValues` is a one-shot snapshot that won't update as
/// a transfer advances). Inert when sync is off or no iCloud account is present: the
/// query simply returns no results, so every book reads as `.synced`.
///
/// MainActor-bound: `NSMetadataQuery` delivers notifications on the thread that
/// started it, and the published `states` drive SwiftUI.
@MainActor
@Observable
final class CloudSyncMonitor {
    /// Books in a non-`.synced` transfer state, keyed by file name (== `Book.fileName`).
    /// A file absent from the map is fully synced (or not a ubiquitous item).
    private(set) var states: [String: BookCloudState] = [:]

    /// Set by `RootView` when sync is intended (`CloudSyncPreference.isEnabled`) but
    /// no usable iCloud account is present. While true, every book reports
    /// `.unavailable` rather than a misleading `.synced`. Recomputed on account changes.
    var unreachable = false

    @ObservationIgnored private let query = NSMetadataQuery()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var started = false

    /// Begins watching the container. Idempotent — only the first call starts the
    /// query. Call once sync is known to be on (otherwise it just stays empty).
    func start() {
        guard !started else { return }
        started = true
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE[c] %@", NSMetadataItemFSNameKey, "*.m4b")
        query.valueListAttributes = [
            NSMetadataUbiquitousItemIsUploadedKey,
            NSMetadataUbiquitousItemIsUploadingKey,
            NSMetadataUbiquitousItemPercentUploadedKey,
            NSMetadataUbiquitousItemDownloadingStatusKey,
            NSMetadataUbiquitousItemIsDownloadingKey,
            NSMetadataUbiquitousItemPercentDownloadedKey,
        ]
        let center = NotificationCenter.default
        for name: NSNotification.Name in [
            .NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate,
        ] {
            observers.append(
                center.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                })
        }
        query.start()
    }

    /// The transfer state for a given book file. Defaults to `.synced` for anything
    /// the query isn't tracking (already in sync, local-only, or sync off).
    func state(for fileName: String) -> BookCloudState {
        if unreachable { return .unavailable }
        return states[fileName] ?? .synced
    }

    private func refresh() {
        // Freeze the result set while we read it; the query keeps collecting changes
        // and re-posts once updates are re-enabled.
        query.disableUpdates()
        defer { query.enableUpdates() }

        var next: [String: BookCloudState] = [:]
        for item in (query.results as? [NSMetadataItem] ?? []) {
            guard let name = item.value(forAttribute: NSMetadataItemFSNameKey) as? String else {
                continue
            }
            if let state = Self.transferState(of: item) { next[name] = state }
        }
        // Only republish when the map actually changed — NSMetadataQuery fires on every
        // byte of transfer progress, but reassigning an unchanged `states` would still
        // invalidate every view observing it (the whole library grid) on each tick.
        if next != states { states = next }
    }

    /// Derives the badge-worthy transfer state from one metadata item, or `nil` when
    /// the file is fully synced (local + uploaded) and needs no badge. Download is
    /// resolved before upload: a not-yet-downloaded file is the more user-visible
    /// state, and a freshly downloaded file may briefly still report "not uploaded".
    private static func transferState(of item: NSMetadataItem) -> BookCloudState? {
        let downloadStatus =
            item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
        let isDownloaded =
            downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent
            || downloadStatus == NSMetadataUbiquitousItemDownloadingStatusDownloaded

        if !isDownloaded {
            let isDownloading =
                item.value(forAttribute: NSMetadataUbiquitousItemIsDownloadingKey) as? Bool ?? false
            if isDownloading {
                let percent =
                    item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey)
                    as? Double
                return .downloading(fraction: percent.map { $0 / 100 })
            }
            return .cloudOnly
        }

        // Downloaded locally: only the upload direction can still be pending. The
        // "isUploaded" key can be momentarily absent both for a fully-synced file AND for
        // one whose upload hasn't been reported yet. Only treat a missing key as synced
        // when there's no positive evidence of an in-flight upload (actively uploading, or
        // a reported percent below 100) — otherwise a still-uploading file would falsely
        // read as `.synced` and the user might evict their only local copy.
        let isUploading =
            item.value(forAttribute: NSMetadataUbiquitousItemIsUploadingKey) as? Bool ?? false
        let percentUp =
            item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double
        let uploaded: Bool
        if let reported = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool {
            uploaded = reported
        } else {
            uploaded = !(isUploading || (percentUp.map { $0 < 100 } ?? false))
        }
        if !uploaded {
            return .uploading(fraction: percentUp.map { $0 / 100 })
        }
        return nil
    }
}
