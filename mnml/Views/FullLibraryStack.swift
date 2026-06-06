//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI

/// The Library tab: the full, configurable library page plus its Book-detail
/// navigation. Sibling to LibraryStack (the Home tab) — both share the
/// `bookDetailDestination` push, so a tapped book opens the same detail screen
/// whether it was reached from Home or here.
struct FullLibraryStack: View {
    @Environment(PlayerEngine.self) private var engine
    /// Owned by RootView (created in its onAppear); used for delete actions.
    let store: LibraryStore?
    /// Slides the full NowPlayingView up — owned by RootView.
    let onOpenPlayer: () -> Void

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            FullLibraryView(
                onPlay: {
                    engine.load($0)
                    engine.play()
                },
                onOpenPlayer: onOpenPlayer,
                onShowDetails: { path.append($0) }
            )
            .bookDetailDestination(path: $path, store: store, onOpenPlayer: onOpenPlayer)
        }
    }
}
