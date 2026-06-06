//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI

/// The shared action set for a book, used as the content of a `Menu` (the row's ⋯ and
/// the detail page's ⋯) and of a grid cell's `.contextMenu`. Defined once so new
/// actions are added in a single place.
///
/// `onShowDetails` is optional: pass it where "Title Details" makes sense (library
/// row, grid cell); omit it on the detail page, which is already showing details.
struct BookActionsMenu: View {
    let book: Book
    /// Optional. When provided (grid long-press), renders a "Play"/"Resume" item.
    /// Omitted where a dedicated play control already exists (rows, detail page).
    var onPlay: (() -> Void)? = nil
    var onShowDetails: (() -> Void)? = nil
    /// Optional. When provided, renders "Edit Details" (opens the edit sheet). Callers
    /// that present the sheet (detail page, library row, grid cell) pass it; omit it where
    /// editing shouldn't be offered.
    var onEdit: (() -> Void)? = nil
    /// Optional. When provided (grid cells), renders a "Select" item that enters
    /// multi-select mode. Omitted (nil) on the detail page, where it doesn't apply.
    var onSelect: (() -> Void)? = nil
    let onMarkFinished: () -> Void
    let onResetProgress: () -> Void
    /// Optional. When provided (file exists locally), renders a "Share" item that opens
    /// the system share sheet for the audio file. Callers gate it on
    /// `DownloadState.canShare(for:)`; cloud-only books pass nil.
    var shareItem: SharedAudiobook? = nil
    /// Optional. When provided, renders "Remove Download" (evict the local copy).
    /// Callers pass it only when sync is on AND the file is downloaded
    /// (`DownloadState.canRemoveDownload`); otherwise it's omitted.
    var onRemoveDownload: (() -> Void)? = nil
    let onDelete: () -> Void

    var body: some View {
        if let onPlay {
            Button {
                onPlay()
            } label: {
                Label(book.progressSeconds > 0 ? "Resume" : "Play", systemImage: "play.fill")
            }
            Divider()
        }
        if let onSelect {
            Button {
                onSelect()
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }
            Divider()
        }
        if let onShowDetails {
            Button {
                onShowDetails()
            } label: {
                Label("Title Details", systemImage: "info.circle")
            }
            Divider()
        }
        if let onEdit {
            Button {
                onEdit()
            } label: {
                Label("Edit Details", systemImage: "pencil")
            }
            Divider()
        }
        // "Mark as Finished" is offered whenever the book isn't already finished — including
        // not-yet-started books. "Reset Progress" only when there's progress to clear.
        if !LibraryArrangement.isFinished(book) {
            Button {
                onMarkFinished()
            } label: {
                Label("Mark as Finished", systemImage: "checkmark.circle")
            }
            if book.progressSeconds > 0 {
                Button {
                    onResetProgress()
                } label: {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
            Divider()
        }
        if let shareItem {
            ShareLink(
                item: shareItem,
                preview: SharePreview(shareItem.title, image: shareItem.previewImage)
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Divider()
        }
        if let onRemoveDownload {
            Button {
                onRemoveDownload()
            } label: {
                Label("Remove Download", systemImage: "icloud.slash")
            }
            Divider()
        }
        // .tint(.red) so the trash glyph matches the destructive red text — without it
        // the icon inherits the app's accent (blue) tint while only the label goes red.
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
    }
}
