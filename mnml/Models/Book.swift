//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    var narrator: String?
    var fileName: String = ""
    @Attribute(.externalStorage) var artworkData: Data?
    var tint: String = ""
    var durationSeconds: Double = 0
    var progressSeconds: Double = 0
    var speed: Double = 1.0
    var dateAdded: Date = Date.distantPast
    var lastPlayedAt: Date?
    /// The source file's extension at import time, lowercased (`"m4b"` or
    /// `"m4a"`). `.m4a` files are stored on disk as `.m4b` (same container), so
    /// this is the only record of the original format. `nil` for books imported
    /// before this was tracked. Optional-with-default keeps the CloudKit schema valid.
    var originalExtension: String?

    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter]? = []

    init(
        id: UUID = UUID(), title: String, author: String, narrator: String?,
        fileName: String, artworkData: Data?, tint: String,
        durationSeconds: Double, dateAdded: Date, originalExtension: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.narrator = narrator
        self.fileName = fileName
        self.artworkData = artworkData
        self.tint = tint
        self.durationSeconds = durationSeconds
        self.progressSeconds = 0
        self.speed = 1.0
        self.dateAdded = dateAdded
        self.lastPlayedAt = nil
        self.originalExtension = originalExtension
    }

    /// Memberwise-default initializer required for CloudKit schema compatibility
    /// (and used by tests). Real imports use the designated initializer above.
    init() {}

    /// Chapters in playback order.
    var orderedChapters: [Chapter] {
        (chapters ?? []).sorted { $0.order < $1.order }
    }

    var chapterDurations: [Double] { orderedChapters.map(\.duration) }
}
