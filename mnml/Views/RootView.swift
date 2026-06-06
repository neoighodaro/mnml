//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(PlayerEngine.self) private var engine
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @Environment(ICloudAccountMonitor.self) private var account
    @AppStorage(CloudSyncPreference.storageKey) private var iCloudSyncEnabled = false
    @Environment(\.modelContext) private var context
    // Most-recently-played first, so the mini-player can restore the last book on launch.
    @Query(sort: \Book.lastPlayedAt, order: .reverse) private var books: [Book]
    @AppStorage("appearance") private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(L.languageKey) private var languageRaw = AppLanguage.en.rawValue
    @State private var store: LibraryStore?
    @State private var showPlayer = false
    // Hides the mini-player while the full player is up. Set true the instant the player
    // opens (before it covers the bar) and false the instant it starts dismissing (while
    // it still covers the bar), so the mini-player is never seen mid-mount.
    @State private var playerVisible = false

    private let playerAnim = Animation.spring(response: 0.42, dampingFraction: 0.86)
    // Dismiss with a finite-duration curve so the slide ends crisply at a known time, rather
    // than a spring whose asymptotic tail keeps nudging the last pixels after the main motion.
    private let playerCloseAnim = Animation.easeInOut(duration: 0.3)

    // Distance the player slides to be fully off-screen. `.move(edge:.bottom)` translated the
    // view by its OWN frame height, but the player's frame is safe-area-inset (its content
    // stays inset by design; only the background bleeds), so the move stopped a home-indicator's
    // height short and left a strip pinned at the bottom that only vanished when the view was
    // finally removed — the "stays at the bottom, then pops" hitch. Driving the transition with
    // an explicit offset equal to the full window height carries it entirely off. Measured by
    // the background reader below; the generous default just covers the first frame.
    @State private var dismissTravel: CGFloat = 2000

    private var appearance: Appearance { Appearance(rawValue: appearanceRaw) ?? .system }
    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    var body: some View {
        // The player is layered OVER the library in a ZStack (not a fullScreenCover) so
        // dragging it down reveals the real library underneath — one continuous UI, not a
        // black void. It's opaque (bg ignores safe area) so it fully hides the library when up.
        ZStack {
            TabContainer(
                store: store,
                onOpenPlayer: { openPlayer() },
                miniPlayerHidden: playerVisible
            )

            if showPlayer {
                NowPlayingView(onClose: { closePlayer() })
                    // Slide the FULL window height (not the inset frame height a `.move`
                    // transition would use) so the player clears the screen completely.
                    .transition(.offset(y: dismissTravel))
                    .zIndex(1)
            }
        }
        // Measure the real window height (inset content + safe areas) without disturbing
        // layout — Color.clear background — so `dismissTravel` reflects the whole screen.
        .background {
            GeometryReader { proxy in
                Color.clear.onAppear {
                    dismissTravel =
                        proxy.size.height
                        + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                }
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, Locale(identifier: language.rawValue))
        // Widget deep links. `mnml://nowplaying` surfaces the full player when a book is
        // loaded; `mnml://library` just foregrounds the app (the OS does that by opening
        // the URL — no extra routing needed).
        .onOpenURL { url in
            switch url.host {
            case WidgetConstants.nowPlayingHost:
                if engine.currentBook != nil { openPlayer() }
            case WidgetConstants.libraryHost:
                break
            default:
                break
            }
        }
        // On launch, restore the last-played book into the engine (paused) so the mini
        // player reappears and can resume. Wait for the iCloud Books directory to be
        // resolved first, so we never load against a stale path; pass autoDownload:false
        // so restoring the mini player never pulls a file the user didn't ask to play.
        .task {
            await LibraryFileSync.waitUntilReady()
            await account.refresh()
            applyAccountState()
            // Collapse any duplicate records that synced in from another device before we
            // restore, so the mini player can't latch onto a soon-to-be-removed duplicate.
            LibraryStore(context: context).reconcileDuplicates()
            restoreLastPlayed()
        }
        // The book list can arrive AFTER this view's first `.task` on a freshly-synced
        // device (CloudKit hydrates asynchronously). Retry the restore when it lands.
        .onChange(of: books.count) { restoreLastPlayed() }
        // Account can change at runtime (sign-in/out) — keep the badge + query in step
        // without an app restart.
        .onChange(of: account.availability) { applyAccountState() }
        .onAppear { if store == nil { store = LibraryStore(context: context) } }
    }

    /// Restores the most-recently-played book into the engine (paused) so the mini player
    /// reappears on launch. The `@Query` is sorted by `lastPlayedAt` descending, so the
    /// first book that has been played (or carries progress) is the one to resume — unlike
    /// the old `progressSeconds > 0` filter, this still restores a book rewound to 0.
    /// Idempotent and safe to retry as the synced library hydrates; `autoDownload: false`
    /// so restoring never pulls a file the user didn't ask to play.
    private func restoreLastPlayed() {
        guard engine.currentBook == nil,
            let last = books.first(where: { $0.lastPlayedAt != nil || $0.progressSeconds > 0 })
        else { return }
        engine.load(last, autoDownload: false)
    }

    /// Reflects the live account state onto the file monitor: badge books as
    /// `.unavailable` when sync is intended but no usable account is present, and
    /// start the transfer query only when sync can actually happen.
    private func applyAccountState() {
        syncMonitor.unreachable = iCloudSyncEnabled && !account.isSyncable
        if iCloudSyncEnabled, account.isSyncable {
            syncMonitor.start()
        }
    }

    private func openPlayer() {
        playerVisible = true  // hide the mini bar immediately as the player slides up over it
        withAnimation(playerAnim) { showPlayer = true }
    }

    /// Unhide the mini bar up front — while the full player is still opaque and covering
    /// the whole screen — then slide the player down. Mounting it now lets the bottom
    /// accessory run its insertion animation hidden behind the player, so it's already
    /// settled and populated when the player slides away (no blank pop-in at the end).
    private func closePlayer() {
        playerVisible = false
        withAnimation(playerCloseAnim) {
            showPlayer = false
        }
    }
}
