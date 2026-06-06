//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI
import UniformTypeIdentifiers

/// Wraps a book's audio file for the system share sheet. Conforms to `Transferable` so a
/// `ShareLink` can export it. The export runs lazily — only when the user actually picks a
/// share target — so the per-render menu body never touches the filesystem.
///
/// On disk files are named `<UUID>.m4b`; to hand the recipient a meaningful name we
/// hard-link (falling back to copy) the real file to a temp file named after the title.
struct SharedAudiobook: Transferable {
    let fileURL: URL
    let title: String
    let artworkData: Data?

    init(book: Book) {
        self.fileURL = M4BImporter.fileURL(for: book.fileName)
        self.title = book.title
        self.artworkData = book.artworkData
    }

    /// A path-safe, title-based filename for the shared copy. Pure — unit-tested.
    static func suggestedFileName(for title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters)
        let cleaned = String(title.unicodeScalars.filter { !invalid.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = cleaned.isEmpty ? "Audiobook" : cleaned
        return base + ".m4b"
    }

    /// Cover for the share sheet preview; falls back to an SF Symbol when artwork is absent.
    var previewImage: Image {
        if let data = artworkData, let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        }
        return Image(systemName: "headphones")
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .audio) { shared in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(suggestedFileName(for: shared.title))
            // Replace any stale temp from a previous share of a same-titled book.
            try? FileManager.default.removeItem(at: dest)
            do {
                // Instant, no data copy — works when source and temp share a volume.
                try FileManager.default.linkItem(at: shared.fileURL, to: dest)
            } catch {
                // Cross-volume (e.g. iCloud Drive container) — fall back to a real copy.
                try FileManager.default.copyItem(at: shared.fileURL, to: dest)
            }
            return SentTransferredFile(dest)
        }
    }
}
