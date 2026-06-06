//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import PhotosUI
import SwiftData
import SwiftUI

/// Modal sheet for editing a book's title/author/narrator, cover photo, and tint.
/// Editing state is local and seeded from the book on init; the `Book` model is mutated
/// and saved only on Save. Cancel discards by never writing. No file/filename changes —
/// the filename is the book's UUID, decoupled from metadata.
struct EditBookView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @State private var title: String
    @State private var author: String
    @State private var narrator: String
    @State private var tint: String
    @State private var artworkData: Data?
    @State private var photoItem: PhotosPickerItem?

    init(book: Book) {
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _narrator = State(initialValue: book.narrator ?? "")
        _tint = State(initialValue: book.tint)
        _artworkData = State(initialValue: book.artworkData)
    }

    private var hasChanges: Bool {
        BookEdit.clean(title) != book.title
            || BookEdit.clean(author) != book.author
            || BookEdit.normalizedNarrator(narrator) != book.narrator
            || tint != book.tint
            || artworkData != book.artworkData
    }
    private var canSave: Bool { BookEdit.canSave(title: title, hasChanges: hasChanges) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    coverSection
                    field("Title", text: $title)
                    field("Author", text: $author)
                    field("Narrator", text: $narrator)
                    Text(
                        "Changes apply only in mnml and can't be undone — the original file isn't modified, and embedded details can't be restored."
                    )
                    .font(Typography.body(12)).foregroundStyle(Theme.text3)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 14)
            }
            .background(Theme.bg)
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.tap()
                        dismiss()
                    }
                    .foregroundStyle(Theme.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Theme.accent : Theme.text3)
                        .disabled(!canSave)
                }
            }
            .onChange(of: photoItem) { _, item in loadPhoto(item) }
        }
    }

    private let coverSize: CGFloat = 240

    /// Cover preview shown large and centered, mirroring the Now Playing hero, with the
    /// contextual control directly beneath it: a "Remove Photo" action when artwork is set,
    /// otherwise a "Choose Photo" picker plus the tint swatches. (Tint only affects the
    /// typographic fallback, so it's shown only when there's no photo.)
    @ViewBuilder private var coverSection: some View {
        VStack(spacing: 18) {
            CoverView(
                title: BookEdit.clean(title).isEmpty ? book.title : title,
                tint: tint, artworkData: artworkData, size: coverSize, radius: 18
            )
            .shadow(color: .black.opacity(0.2), radius: 18, y: 12)
            if artworkData != nil {
                Button(role: .destructive) {
                    Haptics.tap()
                    artworkData = nil
                    photoItem = nil
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                        .font(Typography.buttonLabel).foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo")
                        .font(Typography.buttonLabel).foregroundStyle(Theme.accent)
                }
                tintRow
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tintRow: some View {
        HStack(spacing: 12) {
            ForEach(CoverTint.all, id: \.self) { name in
                Circle()
                    .fill(CoverTint.pair(name).bg)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle().strokeBorder(Theme.accent, lineWidth: name == tint ? 2 : 0)
                            .padding(-3)
                    )
                    .contentShape(Circle())
                    .onTapGesture {
                        Haptics.tap()
                        tint = name
                    }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrowStyle()
            TextField(label, text: text)
                .font(Typography.body(16)).foregroundStyle(Theme.text)
                .tint(Theme.accent)
                .padding(12)
                .background(
                    Theme.track(scheme), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
                let prepared = ArtworkImage.prepared(from: data)
            {
                artworkData = prepared
            }
        }
    }

    private func save() {
        Haptics.tap()
        book.title = BookEdit.clean(title)
        book.author = BookEdit.clean(author)
        book.narrator = BookEdit.normalizedNarrator(narrator)
        book.tint = tint
        book.artworkData = artworkData
        try? context.save()
        dismiss()
    }
}
