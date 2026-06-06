//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

struct FolderScannerTests {
    /// Builds a temp directory tree and returns its root. Caller removes it.
    private func makeTree() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "scan-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        // level 1: a book at the root + a non-audiobook file
        try Data().write(to: root.appendingPathComponent("root-book.m4b"))
        try Data().write(to: root.appendingPathComponent("notes.txt"))

        // level 2: a book inside an immediate subfolder
        let sub = root.appendingPathComponent("Author A", isDirectory: true)
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data().write(to: sub.appendingPathComponent("sub-book.m4b"))

        // level 3: a book two subfolders down — must NOT be found
        let deep = sub.appendingPathComponent("Disc 1", isDirectory: true)
        try fm.createDirectory(at: deep, withIntermediateDirectories: true)
        try Data().write(to: deep.appendingPathComponent("deep-book.m4b"))

        return root
    }

    @Test func findsRootAndOneLevelDownButNotDeeper() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let names = FolderScanner.findM4Bs(in: root).map { $0.lastPathComponent }
        #expect(names.contains("root-book.m4b"))
        #expect(names.contains("sub-book.m4b"))
        #expect(!names.contains("deep-book.m4b"))
    }

    @Test func ignoresNonM4BFiles() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let names = FolderScanner.findM4Bs(in: root).map { $0.lastPathComponent }
        #expect(!names.contains("notes.txt"))
    }

    @Test func matchesExtensionCaseInsensitively() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "scan-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("LOUD.M4B"))

        #expect(FolderScanner.findM4Bs(in: root).count == 1)
    }

    @Test func emptyFolderReturnsEmpty() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "scan-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        #expect(FolderScanner.findM4Bs(in: root).isEmpty)
    }

    @Test func topLevelFindsRootFilesOnly() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let names = FolderScanner.findTopLevelM4Bs(in: root).map { $0.lastPathComponent }
        #expect(names.contains("root-book.m4b"))
        #expect(!names.contains("sub-book.m4b"))  // one level down is NOT scanned
        #expect(!names.contains("notes.txt"))
    }

    @Test func topLevelMatchesExtensionCaseInsensitively() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "scan-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("LOUD.M4B"))

        #expect(FolderScanner.findTopLevelM4Bs(in: root).count == 1)
    }

    @Test func topLevelEmptyFolderReturnsEmpty() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "scan-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        #expect(FolderScanner.findTopLevelM4Bs(in: root).isEmpty)
    }

    @Test func cloudScanFindsRealAndPlaceholderFiles() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "cloud-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        // a downloaded book, and an undownloaded one (iCloud placeholder form)
        try Data().write(to: root.appendingPathComponent("mistborn.m4b"))
        try Data().write(to: root.appendingPathComponent(".dune.m4b.icloud"))

        let names = FolderScanner.findTopLevelM4BsIncludingCloud(in: root)
            .map { $0.lastPathComponent }
        #expect(names.contains("mistborn.m4b"))
        #expect(names.contains("dune.m4b"))  // placeholder mapped back to the real name
        #expect(!names.contains(".dune.m4b.icloud"))
    }

    @Test func cloudScanCollapsesRealAndPlaceholderOfSameName() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "cloud-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try Data().write(to: root.appendingPathComponent("dune.m4b"))
        try Data().write(to: root.appendingPathComponent(".dune.m4b.icloud"))

        let dune = FolderScanner.findTopLevelM4BsIncludingCloud(in: root)
            .filter { $0.lastPathComponent == "dune.m4b" }
        #expect(dune.count == 1)  // de-duplicated to a single URL
    }

    @Test func findsM4AFilesAndStillIgnoresOtherAudio() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "scan-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("book.m4a"))
        try Data().write(to: root.appendingPathComponent("song.mp3"))

        let names = FolderScanner.findM4Bs(in: root).map { $0.lastPathComponent }
        #expect(names.contains("book.m4a"))
        #expect(!names.contains("song.mp3"))
    }

    @Test func mapsM4APlaceholderToRealURL() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "scan-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent(".dune.m4a.icloud"))

        let names = FolderScanner.findTopLevelM4BsIncludingCloud(in: root)
            .map { $0.lastPathComponent }
        #expect(names.contains("dune.m4a"))
        #expect(!names.contains(".dune.m4a.icloud"))
    }

    @Test func cloudScanIgnoresNonAudioAndDeeperLevels() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "cloud-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try Data().write(to: root.appendingPathComponent("notes.txt"))
        try Data().write(to: root.appendingPathComponent(".notes.txt.icloud"))  // non-audio placeholder
        let sub = root.appendingPathComponent("Series", isDirectory: true)
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data().write(to: sub.appendingPathComponent("deep.m4b"))  // one level down

        let names = FolderScanner.findTopLevelM4BsIncludingCloud(in: root)
            .map { $0.lastPathComponent }
        #expect(names.isEmpty)  // no top-level audiobooks; non-audio + subfolder ignored
    }
}
