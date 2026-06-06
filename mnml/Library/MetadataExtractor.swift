//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import AVFoundation
import Foundation

/// Reads title/author/artwork/duration/chapters from an M4B via AVFoundation.
/// UI-free; returns a plain value type the importer turns into SwiftData models.
struct ExtractedMetadata {
    var title: String?
    var author: String?
    var artworkData: Data?
    var duration: Double
    var chapters: [ExtractedChapter]
}

struct ExtractedChapter {
    var title: String
    var startTime: Double
    var duration: Double
}

// `nonisolated` opts out of the project's default MainActor isolation so the
// AVFoundation parsing runs off the main thread when called from the importer's
// `@concurrent` copy step (rather than inheriting the caller's actor).
nonisolated enum MetadataExtractor {
    static func extract(from url: URL) async throws -> ExtractedMetadata {
        let asset = AVURLAsset(url: url)

        let duration = try await asset.load(.duration).seconds
        let common = try await asset.load(.commonMetadata)

        let title = try await firstString(common, .commonIdentifierTitle)
        let author = try await firstString(common, .commonIdentifierArtist)
        let artwork = try await firstData(common, .commonIdentifierArtwork)

        let chapters = try await loadChapters(asset: asset, fallbackDuration: duration)

        return ExtractedMetadata(
            title: title, author: author, artworkData: artwork,
            duration: duration, chapters: chapters
        )
    }

    private static func loadChapters(asset: AVURLAsset, fallbackDuration: Double) async throws
        -> [ExtractedChapter]
    {
        let locales = try await asset.load(.availableChapterLocales)
        let languages =
            locales.isEmpty
            ? Locale.preferredLanguages
            : locales.map(\.identifier)
        let groups = try await asset.loadChapterMetadataGroups(
            bestMatchingPreferredLanguages: languages)

        var result: [ExtractedChapter] = []
        for (i, group) in groups.enumerated() {
            let start = group.timeRange.start.seconds
            let dur = group.timeRange.duration.seconds
            let titleItem =
                AVMetadataItem.metadataItems(
                    from: group.items, filteredByIdentifier: .commonIdentifierTitle
                )
                .first
            let title = try? await titleItem?.load(.stringValue)
            result.append(
                ExtractedChapter(
                    title: title ?? "Chapter \(i + 1)",
                    startTime: start,
                    duration: dur.isFinite && dur > 0 ? dur : 0
                ))
        }

        if result.isEmpty {
            // No embedded chapters → one synthetic chapter spanning the whole book.
            return [ExtractedChapter(title: "Chapter 1", startTime: 0, duration: fallbackDuration)]
        }
        return result
    }

    private static func firstString(_ items: [AVMetadataItem], _ id: AVMetadataIdentifier)
        async throws -> String?
    {
        let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first
        return try await item?.load(.stringValue)
    }

    private static func firstData(_ items: [AVMetadataItem], _ id: AVMetadataIdentifier)
        async throws -> Data?
    {
        let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first
        return try await item?.load(.dataValue)
    }
}
