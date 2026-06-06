//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI

/// The cover-grid cell visual: artwork with cloud badge/scrim, an optional
/// selection overlay, and the author label. Purely presentational — the owner
/// wraps it in a Button (tap action) and attaches the `.contextMenu`.
struct BookGridCell: View {
    let book: Book
    let size: CGFloat
    /// Cloud transfer state to render; pass `.synced` while selecting to hide badges.
    let cloudState: BookCloudState
    var isSelecting: Bool = false
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverView(
                title: book.title, tint: book.tint,
                artworkData: book.artworkData, size: size, radius: 10
            )
            .cloudBadgeScrim(for: isSelecting ? .synced : cloudState, radius: 10)
            .overlay(alignment: .topLeading) {
                if !isSelecting {
                    CloudStateBadge(state: cloudState).padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelecting { selectionBadge(isSelected: isSelected).padding(8) }
            }
            .overlay {
                if isSelecting && isSelected {
                    RoundedRectangle(cornerRadius: 10).stroke(Theme.accent, lineWidth: 2)
                }
            }
            Text(book.author)
                .font(Typography.rowAuthor)
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }

    private func selectionBadge(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Theme.accent : Color.black.opacity(0.25))
                .frame(width: 22, height: 22)
            Circle()
                .stroke(Color.white.opacity(isSelected ? 0 : 0.9), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
