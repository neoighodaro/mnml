//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation

/// Reads/writes the recent-book snapshot and its artwork thumbnail in the App Group.
/// `UserDefaults` and the container directory are injectable so unit tests can use a
/// private suite + temp dir (the real App Group container isn't available in tests).
nonisolated struct WidgetSnapshotStore {
    private let defaults: UserDefaults
    private let containerDir: URL

    /// Production initializer — resolves the shared App Group container.
    init() {
        self.defaults = UserDefaults(suiteName: WidgetConstants.appGroup) ?? .standard
        self.containerDir =
            FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetConstants.appGroup)
            ?? FileManager.default.temporaryDirectory
    }

    /// Test initializer.
    init(defaults: UserDefaults, containerDir: URL) {
        self.defaults = defaults
        self.containerDir = containerDir
    }

    private var artworkURL: URL {
        containerDir.appendingPathComponent(WidgetConstants.artworkFileName)
    }

    // MARK: snapshot

    func read() -> RecentSnapshot {
        guard let data = defaults.data(forKey: WidgetConstants.snapshotKey),
            let snap = try? JSONDecoder().decode(RecentSnapshot.self, from: data)
        else { return .empty }
        return snap
    }

    func write(_ snapshot: RecentSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: WidgetConstants.snapshotKey)
    }

    /// Optimistically flip just the play/pause flag (used by the widget intent for an
    /// instant UI response before the app confirms). No-op when empty.
    func setPlaying(_ playing: Bool) {
        let current = read()
        guard !current.isEmpty else { return }
        write(
            RecentSnapshot(
                bookID: current.bookID, title: current.title,
                author: current.author, tint: current.tint,
                isPlaying: playing, hasArtwork: current.hasArtwork))
    }

    // MARK: artwork

    /// Writes (or, when `data` is nil, clears) the artwork thumbnail file.
    func writeArtwork(_ data: Data?) {
        if let data {
            try? data.write(to: artworkURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: artworkURL)
        }
    }

    func readArtworkData() -> Data? {
        try? Data(contentsOf: artworkURL)
    }
}
