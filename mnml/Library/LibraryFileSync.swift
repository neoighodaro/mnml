//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// One-time launch setup for the files layer. Resolves where `Books/` lives this
/// launch, migrates any local files into the iCloud container when sync is on, and
/// pins the directory on `M4BImporter`. Like Phase 1's container, this is fixed per
/// launch — toggling sync takes effect on the next restart.
///
/// MUST run off the main thread: it fetches the ubiquity container (can block) and
/// moves files. Started once from `MnmlApp.init` via `start()`.
enum LibraryFileSync {
    /// The launch configuration task (resolve directory → migrate → pin importer).
    /// Started once from `MnmlApp.init`; awaited by the launch playback-restore so it
    /// never reads a stale `Books/` directory before the iCloud container is pinned.
    nonisolated(unsafe) private(set) static var task: Task<Void, Never>?

    /// Kicks off launch configuration off the main thread. Call once at launch.
    @discardableResult
    static func start() -> Task<Void, Never> {
        let t = Task.detached(priority: .userInitiated) { await configureAtLaunch() }
        task = t
        return t
    }

    /// Suspends until launch configuration has finished (the active `Books/` directory
    /// is resolved and pinned). Returns immediately if it already completed or never
    /// started, so callers degrade gracefully to the local-directory fallback.
    static func waitUntilReady() async {
        await task?.value
    }

    static func configureAtLaunch() {
        let syncEnabled = CloudSyncPreference().isEnabled
        let accountAvailable = ICloudAccount.isAvailable
        let localDocuments =
            FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]

        let useCloud = ModelStoreFactory.shouldEnableCloudKit(
            syncEnabled: syncEnabled, accountAvailable: accountAvailable)
        let ubiquityDocuments = useCloud ? UbiquityContainer.documentsURL() : nil

        let books = FileLocation.booksDirectory(
            syncEnabled: syncEnabled, accountAvailable: accountAvailable,
            ubiquityDocuments: ubiquityDocuments, localDocuments: localDocuments)

        // Sync on and the container resolved to a different place than local:
        // move any leftover local files into the container so the rest of the app
        // sees a single, populated location (the no-duplicate guarantee).
        if let ubiquityDocuments {
            let localBooks = localDocuments.appendingPathComponent("Books", isDirectory: true)
            if localBooks.path != books.path {
                BookFileMigrator.migrate(from: localBooks, to: books)
            }
            // Create the user-visible "Import" drop folder so it's discoverable in Files
            // before the first import.
            let importDir = ubiquityDocuments.appendingPathComponent("Import", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: importDir, withIntermediateDirectories: true)
        }

        M4BImporter.useBooksDirectory(books)
    }
}
