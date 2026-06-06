//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI

/// One library/continue-listening row: tap-to-play cover + title/author/progress,
/// a play-pause control, and the shared ⋯ actions menu. Reads the player and sync
/// monitor from the environment; all mutations are delegated via closures so the
/// owning view controls confirmation dialogs.
struct BookRow: View {
    let book: Book
    let onPlay: (Book) -> Void
    /// Slides up the full player. Invoked when the row's book is the one already
    /// playing — tapping it then surfaces the player rather than restarting playback.
    let onOpenPlayer: () -> Void
    let onShowDetails: (Book) -> Void
    let onEdit: (Book) -> Void
    let onMarkFinished: (Book) -> Void
    let onResetProgress: (Book) -> Void
    let onRemoveDownload: (Book) -> Void
    let onDelete: (Book) -> Void

    @Environment(PlayerEngine.self) private var engine
    @Environment(CloudSyncMonitor.self) private var syncMonitor

    var body: some View {
        let total = BookMath.totalDuration(book.chapterDurations)
        let pct = total > 0 ? book.progressSeconds / total : 0
        let isCurrent = engine.currentBook?.id == book.id
        let isPlayingThis = isCurrent && engine.isPlaying
        return HStack(spacing: 10) {
            // Tapping the row body opens the player when this book is already playing;
            // otherwise it starts/resumes playback (the dedicated play button beside it
            // still toggles in place either way).
            Button {
                Haptics.tap()
                if isPlayingThis { onOpenPlayer() } else { onPlay(book) }
            } label: {
                HStack(spacing: 15) {
                    CoverView(
                        title: book.title, tint: book.tint, artworkData: book.artworkData, size: 54
                    )
                    .cloudBadgeScrim(for: syncMonitor.state(for: book.fileName), radius: 7)
                    .overlay(alignment: .topLeading) {
                        CloudStateBadge(state: syncMonitor.state(for: book.fileName)).padding(3)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title).font(Typography.rowTitle).tracking(-0.16)
                            .foregroundStyle(Theme.text).lineLimit(1)
                        Text(book.author).font(Typography.rowAuthor).foregroundStyle(Theme.text2)
                        if book.progressSeconds > 0, total > 0 {
                            HStack(spacing: 8) {
                                ProgressBar(fraction: pct).frame(maxWidth: 150, maxHeight: 2)
                                Text(
                                    "\(TimeFormat.fmtLong(max(0, total - book.progressSeconds))) left"
                                )
                                .font(Typography.times).monospacedDigit()
                                .foregroundStyle(Theme.text3)
                            }
                            .padding(.top, 7)
                        }
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                if isPlayingThis { engine.pause() } else { onPlay(book) }
            } label: {
                Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(isCurrent ? Theme.accent : Theme.text2)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.snappy(duration: 0.15), value: isPlayingThis)
                    .frame(width: 34, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                BookActionsMenu(
                    book: book,
                    onShowDetails: { onShowDetails(book) },
                    onEdit: { onEdit(book) },
                    onMarkFinished: { onMarkFinished(book) },
                    onResetProgress: { onResetProgress(book) },
                    shareItem: DownloadState.canShare(for: book)
                        ? SharedAudiobook(book: book) : nil,
                    onRemoveDownload: DownloadState.canRemoveDownload(for: book)
                        ? { onRemoveDownload(book) } : nil,
                    onDelete: { onDelete(book) }
                )
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 16)).foregroundStyle(Theme.text3)
                    .frame(width: 30, height: 44).contentShape(Rectangle())
            }
        }
        .padding(.vertical, 13)
    }
}
