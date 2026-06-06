//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI

struct BookDetailView: View {
    let book: Book
    @Environment(PlayerEngine.self) private var engine
    @Environment(CloudSyncMonitor.self) private var syncMonitor
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    let onBack: () -> Void
    let onPlay: (Double) -> Void
    let onDelete: () -> Void
    @State private var confirmingDelete = false
    @State private var confirmingReset = false
    @State private var editing = false

    private var total: Double { BookMath.totalDuration(book.chapterDurations) }
    private var isCurrent: Bool { engine.currentBook?.id == book.id }
    private var progress: Double { isCurrent ? engine.currentTime : book.progressSeconds }
    private var currentChapterIndex: Int {
        BookMath.locate(progress: progress, durations: book.chapterDurations).index
    }

    private func markFinished() {
        engine.markFinished(book)
        try? context.save()
    }

    private func resetProgress() {
        engine.resetProgress(book)
        try? context.save()
    }

    private var syncOn: Bool { CloudSyncPreference().isEnabled }

    private func removeDownload() {
        Haptics.tap()
        // Keep the book loaded so the mini player can resume it (no-op unless it's the
        // loaded book); tearing down the open file first lets the eviction take.
        engine.releaseDownload(book)
        // Same path the library list uses: the store evicts off the main thread and the
        // cloud-only badge updates itself once the local copy is gone.
        LibraryStore(context: context).removeDownload(book)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CoverView(
                    title: book.title, tint: book.tint, artworkData: book.artworkData,
                    size: 104, radius: 11)
                Text(book.title).font(Typography.detailH1).tracking(-0.95)
                    .foregroundStyle(Theme.text).padding(.top, 20)
                Text(book.author).font(Typography.body(15)).foregroundStyle(Theme.text2)
                    .padding(.top, 7)
                metaLine.padding(.top, 12)
                cloudStatus
                playButton.padding(.top, 22)
                Text("Chapters").eyebrowStyle().padding(.top, 34).padding(.bottom, 4)
                chapterList
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 6)
            .padding(.bottom, Theme.botSafe + Theme.miniPlayerInset)
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .navigationBarBackButtonHidden(true)
        .enablesSwipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.tap()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.text)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    BookActionsMenu(
                        book: book,
                        onEdit: { editing = true },
                        onMarkFinished: { markFinished() },
                        onResetProgress: { confirmingReset = true },
                        shareItem: DownloadState.canShare(for: book)
                            ? SharedAudiobook(book: book) : nil,
                        onRemoveDownload: DownloadState.canRemoveDownload(for: book)
                            ? { removeDownload() } : nil,
                        onDelete: { confirmingDelete = true }
                    )
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.text)
                }
            }
        }
        .confirmationDialog("Delete book?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(DeleteCopy.single(book.title, syncEnabled: syncOn))
        }
        .confirmationDialog("Reset progress?", isPresented: $confirmingReset) {
            Button("Reset") { resetProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(book.title)” will start over from the beginning.")
        }
        .sheet(isPresented: $editing) {
            EditBookView(book: book)
        }
    }

    /// iCloud transfer status under the meta line — the up/down percentage while a
    /// transfer is in flight, or a cloud glyph when the book is only in iCloud (not on
    /// this device). Hidden entirely once the file is fully synced, so the header stays
    /// clean in the common case.
    @ViewBuilder private var cloudStatus: some View {
        let state = syncMonitor.state(for: book.fileName)
        if state != .synced {
            CloudStateBadge(state: state, showsPercent: true).padding(.top, 10)
        }
    }

    private var metaLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let narrator = book.narrator, !narrator.isEmpty {
                Text("Narrated by \(narrator)")
            }
            Text("\(TimeFormat.fmtLong(total)) · \(book.orderedChapters.count) chapters")
        }
        .font(Typography.body(12.5)).foregroundStyle(Theme.text3)
    }

    /// The big primary action. Once this book is the loaded one it becomes a live
    /// transport toggle — "Pause" while it's playing, "Resume · X left" while it's
    /// paused — and acts in place without re-opening the player. For any other book it's
    /// the cold-start Play/Resume that loads it and slides the full player up.
    private var playButton: some View {
        let playingNow = isCurrent && engine.isPlaying
        return Button {
            Haptics.tap(.medium)
            if isCurrent { engine.toggle() } else { onPlay(progress) }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: playingNow ? "pause.fill" : "play.fill")
                    .font(.system(size: 15))
                    .contentTransition(.symbolEffect(.replace))
                Text(
                    playingNow
                        ? "Pause"
                        : (progress > 0
                            ? "Resume · \(TimeFormat.fmtLong(total - progress)) left" : "Play")
                )
                .font(Typography.buttonLabel).tracking(-0.15)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.15), value: playingNow)
    }

    private var chapterList: some View {
        VStack(spacing: 0) {
            ForEach(Array(book.orderedChapters.enumerated()), id: \.offset) { i, ch in
                let current = isCurrent && i == currentChapterIndex
                Button {
                    Haptics.tap()
                    onPlay(BookMath.chapterBase(index: i, durations: book.chapterDurations))
                } label: {
                    HStack(spacing: 14) {
                        Text(String(format: "%02d", i + 1)).font(Typography.chapterNum)
                            .monospacedDigit()
                            .foregroundStyle(current ? Theme.accent : Theme.text3)
                            .fontWeight(current ? .semibold : .regular)
                            .frame(width: 18, alignment: .leading)
                        // Only the playing chapter scrolls long titles; the rest stay
                        // single-line truncated so the list doesn't become a wall of motion.
                        if current {
                            MarqueeText(
                                text: ch.title,
                                font: Typography.body(15, weight: .medium),
                                color: Theme.accent, tracking: -0.15, alignment: .leading)
                        } else {
                            Text(ch.title).font(Typography.chapterTitle).tracking(-0.15)
                                .foregroundStyle(Theme.text)
                                .lineLimit(1).truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(TimeFormat.fmtLong(ch.duration)).font(Typography.body(12.5))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text3)
                    }
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    if i > 0 { Rectangle().fill(Theme.hairline(scheme)).frame(height: 0.5) }
                }
            }
        }
    }
}
