//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation

/// What the widget needs to render the "Recent" book. Written by the app to the App
/// Group, read by the widget. Artwork is NOT inlined — it's a separate thumbnail file
/// (see `WidgetSnapshotStore`) to keep the defaults plist small.
nonisolated struct RecentSnapshot: Codable, Equatable {
    let bookID: String  // Book.id UUID string; "" when nothing has played
    let title: String
    let author: String
    let tint: String  // CoverTint key: clay/sage/slate/sand/plum/mist
    let isPlaying: Bool
    let hasArtwork: Bool

    /// The empty/“nothing played yet” snapshot.
    static let empty = RecentSnapshot(
        bookID: "", title: "", author: "",
        tint: "slate", isPlaying: false, hasArtwork: false)

    var isEmpty: Bool { bookID.isEmpty }
}
