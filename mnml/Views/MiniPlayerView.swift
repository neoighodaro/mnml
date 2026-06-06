//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerEngine.self) private var engine
    let onOpen: () -> Void

    var body: some View {
        // The accessory is always mounted, so the pill must never be empty: when no book is
        // loaded (e.g. right after marking the current one finished) we show a placeholder
        // prompting the user to pick a book, rather than a blank bar.
        if let book = engine.currentBook {
            loadedPill(book)
        } else {
            placeholderPill
        }
    }

    /// Mirrors NowPlayingView: while the file is fetching from iCloud the transport can't act
    /// yet, so the pill shows a spinner and a "Downloading…" line instead of a stale play glyph.
    private var isDownloading: Bool { engine.loadState == .downloading }

    private func loadedPill(_ book: Book) -> some View {
        let chapter = book.orderedChapters[safe: engine.currentChapterIndex]?.title ?? ""
        // Rendered inside the iOS 26 tabViewBottomAccessory, which does NOT supply a glass
        // fill on its own — so we give the content real Liquid Glass via .glassEffect below.
        // Tappable via onTapGesture (not an outer Button) so the inner play/pause Button
        // keeps gesture priority and its tap doesn't also open the player.
        return HStack(spacing: 10) {
            CoverView(
                title: book.title, tint: book.tint, artworkData: book.artworkData,
                size: 34, radius: 10)
            VStack(alignment: .leading, spacing: 1) {
                // Plain truncation (not MarqueeText): the accessory pill is narrow and the
                // system minimizes/animates it, which a perpetual marquee would fight. The
                // full title is shown in the player that opens on tap.
                Text(book.title)
                    .font(Typography.body(14, weight: .medium))
                    .tracking(-0.14)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(isDownloading ? L.string("Downloading…") : chapter)
                    .font(Typography.body(12))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.tap(.medium)
                engine.toggle()
            } label: {
                Group {
                    if isDownloading {
                        ProgressView().tint(Theme.text2)
                    } else {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18)).foregroundStyle(Theme.text)
                            .contentTransition(.symbolEffect(.replace))
                            .animation(.snappy(duration: 0.15), value: engine.isPlaying)
                    }
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain).disabled(isDownloading)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            onOpen()
        }
    }

    /// Empty-state pill: a muted glyph tile and a prompt where the cover and title go. The
    /// layout mirrors `loadedPill` (same heights, trailing transport slot) so the accessory
    /// keeps a stable size, but the transport glyph is dimmed/inert and the pill is not
    /// tappable — there is nothing to open or toggle yet.
    private var placeholderPill: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.text2.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                )
            Text("Select a book to start playing")
                .font(Typography.body(14, weight: .medium))
                .tracking(-0.14)
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Image(systemName: "play.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.text2.opacity(0.4))
                .frame(width: 40, height: 40)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity)
    }
}
