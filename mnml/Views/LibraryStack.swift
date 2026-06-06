//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI

/// The Home tab: the curated shelf (Continue Listening, stats, library preview)
/// plus its Continue-Listening and Book-detail navigation. Extracted from RootView
/// so it can be a TabView tab. The full, configurable library lives in its own tab
/// now, so "See full library" switches tabs rather than pushing a copy here.
struct LibraryStack: View {
    @Environment(PlayerEngine.self) private var engine
    /// Owned by RootView (created in its onAppear); used for delete actions.
    let store: LibraryStore?
    /// Slides the full NowPlayingView up — owned by RootView.
    let onOpenPlayer: () -> Void
    /// Switches the tab bar to the Library tab — what "See full library" does now.
    let onOpenLibraryTab: () -> Void

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            LibraryView(
                onPlay: {
                    engine.load($0)
                    engine.play()
                },
                onOpenPlayer: onOpenPlayer,
                onShowDetails: { path.append($0) },
                onShowContinueListening: { path.append(ContinueListeningRoute()) },
                onShowLibrary: onOpenLibraryTab
            )
            .navigationDestination(for: ContinueListeningRoute.self) { _ in
                ContinueListeningView(
                    onPlay: {
                        engine.load($0)
                        engine.play()
                    },
                    onOpenPlayer: onOpenPlayer,
                    onShowDetails: { path.append($0) }
                )
            }
            .bookDetailDestination(path: $path, store: store, onOpenPlayer: onOpenPlayer)
        }
    }
}

/// The Book-detail push shared by every stack that lists books (Home, Library).
/// The wiring is identical — play loads the book and slides the full player up,
/// delete ejects and pops — so it lives in one place and the stacks stay in step.
private struct BookDetailDestination: ViewModifier {
    @Environment(PlayerEngine.self) private var engine
    let store: LibraryStore?
    @Binding var path: NavigationPath
    let onOpenPlayer: () -> Void

    func body(content: Content) -> some View {
        content.navigationDestination(for: Book.self) { book in
            BookDetailView(
                book: book,
                onBack: { if !path.isEmpty { path.removeLast() } },
                onPlay: { seconds in
                    engine.load(book, startAt: seconds)
                    engine.play()
                    onOpenPlayer()
                },
                onDelete: {
                    engine.eject(book)
                    store?.delete(book)
                    if !path.isEmpty { path.removeLast() }
                }
            )
        }
    }
}

extension View {
    /// Attaches the shared Book-detail destination, bound to `path` so Back and
    /// delete pop the stack that owns it.
    func bookDetailDestination(
        path: Binding<NavigationPath>, store: LibraryStore?, onOpenPlayer: @escaping () -> Void
    ) -> some View {
        modifier(BookDetailDestination(store: store, path: path, onOpenPlayer: onOpenPlayer))
    }
}
