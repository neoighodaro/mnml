//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// The app's tab bar (iOS 26 Liquid Glass): Home (the curated shelf), Library (the
/// full, configurable page), and Settings, plus a `.search`-role tab that renders as
/// the expanded search field at the bottom-right. The now-playing mini-player floats
/// above the bar as the native bottom accessory. A selection binding lets Home's "See
/// full library" jump straight to the Library tab.
struct TabContainer: View {
    let store: LibraryStore?
    let onOpenPlayer: () -> Void
    /// True while the full player is up or animating — hide the mini-player then,
    /// matching RootView's existing `playerVisible` guard.
    let miniPlayerHidden: Bool

    /// Named `TabID` rather than `Tab` so it doesn't shadow SwiftUI's `Tab` view.
    private enum TabID: Hashable { case home, library, settings, search }
    @State private var selection: TabID = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: TabID.home) {
                LibraryStack(
                    store: store, onOpenPlayer: onOpenPlayer,
                    onOpenLibraryTab: { selection = .library })
            }
            Tab("Library", systemImage: "books.vertical", value: TabID.library) {
                FullLibraryStack(store: store, onOpenPlayer: onOpenPlayer)
            }
            Tab("Settings", systemImage: "gearshape", value: TabID.settings) {
                NavigationStack { SettingsView() }
            }
            // No label/icon: a search-role tab renders as the inline search field
            // (the expanded pill), not a plain labeled tab.
            Tab(value: TabID.search, role: .search) {
                SearchView(onOpenPlayer: onOpenPlayer)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if !miniPlayerHidden {
                MiniPlayerView(onOpen: onOpenPlayer)
            }
        }
    }
}
