//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

// Serialized: both tests mutate the one real `Books/` directory, so running
// them in parallel lets one test's transient file pollute the other's
// whole-directory snapshot. One-at-a-time keeps each snapshot stable.
@Suite(.serialized)
struct M4BImporterInboxTests {
    private func fixtureURL() throws -> URL {
        try #require(Bundle(for: BundleToken.self).url(forResource: "sample", withExtension: "m4b"))
    }

    /// Filenames currently sitting in the real Books/ directory.
    private func bookFilenames() -> Set<String> {
        let urls =
            (try? FileManager.default.contentsOfDirectory(
                at: M4BImporter.booksDirectory, includingPropertiesForKeys: nil)) ?? []
        return Set(urls.map { $0.lastPathComponent })
    }

    /// Copies the fixture to a temp source standing in for an Inbox file.
    private func makeInboxFile(named name: String) throws -> URL {
        let fm = FileManager.default
        let src = fm.temporaryDirectory.appendingPathComponent("inbox-\(UUID().uuidString)-\(name)")
        try fm.copyItem(at: try fixtureURL(), to: src)
        return src
    }

    @Test func inspectReadsMetadataWithoutTouchingTheFile() async throws {
        let fm = FileManager.default
        let src = try makeInboxFile(named: "sample.m4b")
        defer { try? fm.removeItem(at: src) }

        let before = bookFilenames()
        let metadata = try await M4BImporter.inspect(src, accessSecurityScope: false)

        #expect(metadata.title == "Sample Book")
        #expect(metadata.duration == 20.0)
        #expect(fm.fileExists(atPath: src.path))  // inspect parses in place — never moves/copies
        #expect(bookFilenames() == before)  // …and never reaches Books/
    }

    @Test func placeMovingInboxMovesFileIntoBooks() async throws {
        let fm = FileManager.default
        let src = try makeInboxFile(named: "sample.m4b")
        defer { try? fm.removeItem(at: src) }  // no-op if the move succeeded

        let fileName = try await M4BImporter.place(movingInbox: src)
        defer { try? fm.removeItem(at: M4BImporter.fileURL(for: fileName)) }

        #expect(!fm.fileExists(atPath: src.path))  // moved out of inbox
        #expect(fm.fileExists(atPath: M4BImporter.fileURL(for: fileName).path))  // now in Books/
    }

    @Test func corruptFileFailsInspectionAndPlacesNothing() async throws {
        let fm = FileManager.default
        let src = fm.temporaryDirectory.appendingPathComponent("bad-\(UUID().uuidString).m4b")
        try Data("not real audio".utf8).write(to: src)
        defer { try? fm.removeItem(at: src) }

        let before = bookFilenames()

        var threw = false
        do { _ = try await M4BImporter.inspect(src, accessSecurityScope: false) } catch {
            threw = true
        }

        #expect(threw)
        // Inspection happens before any copy/move, so a corrupt file never reaches
        // Books/ — there's nothing to orphan. (Emptying the Inbox on a failed import
        // is the caller's job; see LibraryStore.runBatch.)
        #expect(bookFilenames() == before)
    }
}
