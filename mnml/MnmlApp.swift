//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI
import UIKit

@main
struct MnmlApp: App {
    let container: ModelContainer
    @State private var engine: PlayerEngine
    @State private var stats: ListeningStats
    @State private var syncMonitor = CloudSyncMonitor()
    @State private var accountMonitor = ICloudAccountMonitor()

    init() {
        SmartRewindPreference.registerDefault()
        let stats = ListeningStats()
        _stats = State(initialValue: stats)
        _engine = State(initialValue: PlayerEngine(stats: stats))
        container = AppModelContainer.shared
        // Resolve the iCloud Drive Books directory and migrate local files into it
        // off the main thread (the ubiquity container fetch can block). The launch
        // playback-restore awaits this (LibraryFileSync.waitUntilReady) so it never
        // reads a stale directory; until it finishes, M4BImporter falls back to local.
        LibraryFileSync.start()
        Self.configureNavigationBar()
    }

    /// Flat, divider-free navigation bar on the app's background — the header is
    /// type-only chrome, so the bar should read as part of the page, not a tray.
    private static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.bg)
        appearance.shadowColor = .clear
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .environment(stats)
                .environment(syncMonitor)
                .environment(accountMonitor)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}

/// Process-wide SwiftData container. Lives outside the SwiftUI `App` so a background
/// launch — e.g. the widget's `AudioStartingIntent` starting playback with no rendered
/// scene — can resolve a `Book` by id. The app's `.modelContainer` and any in-process
/// intent share this one lazily-created instance.
enum AppModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelStoreFactory.makeContainer(
                syncEnabled: CloudSyncPreference().isEnabled,
                accountAvailable: ICloudAccount.isAvailable
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @MainActor static func fetchBook(id: UUID) -> Book? {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })
        return try? shared.mainContext.fetch(descriptor).first
    }
}
