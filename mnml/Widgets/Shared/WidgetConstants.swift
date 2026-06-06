//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation

/// Single source of truth shared by the app and the widget extension. Both processes
/// must agree on these exact strings, so they live in one dual-membership file.
nonisolated enum WidgetConstants {
    /// App Group container shared by the app and `mnmlWidgets`.
    static let appGroup = "group.com.tapsharp.mnml"

    /// `UserDefaults` key (within the App Group suite) holding the JSON `RecentSnapshot`.
    static let snapshotKey = "recentSnapshot"

    /// Filename of the downscaled artwork thumbnail in the App Group container.
    static let artworkFileName = "recent-artwork.jpg"

    /// Darwin notification posted by the widget intent and observed by the app to
    /// toggle live playback. Darwin names are global; namespace with the bundle id.
    static let toggleDarwinName = "com.tapsharp.mnml.widget.togglePlayback"

    /// Widget kind identifier (must match the `Widget`'s `kind`).
    static let recentKind = "RecentWidget"

    /// Deep-link scheme/hosts. `mnml://nowplaying` opens the player; `mnml://library`
    /// opens the library (empty-state tap).
    static let urlScheme = "mnml"
    static let nowPlayingHost = "nowplaying"
    static let libraryHost = "library"
}
