//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

struct MetadataExtractorTests {
    private func fixtureURL() throws -> URL {
        try #require(Bundle(for: BundleToken.self).url(forResource: "sample", withExtension: "m4b"))
    }

    @Test func extractsDurationAndChapters() async throws {
        let meta = try await MetadataExtractor.extract(from: fixtureURL())
        #expect(meta.duration == 20.0)
        #expect(meta.chapters.count == 2)
        #expect(meta.chapters.first?.startTime == 0)
        #expect(meta.chapters.first?.title == "Chapter One")
        #expect(meta.chapters.last?.title == "Chapter Two")
        #expect(meta.chapters.last?.startTime == 10.0)
    }

    @Test func extractsTitleAndArtwork() async throws {
        let meta = try await MetadataExtractor.extract(from: fixtureURL())
        #expect(meta.title == "Sample Book")
        #expect(meta.author == "Test Author")
        #expect((meta.artworkData?.count ?? 0) > 100)
    }
}

final class BundleToken {}
