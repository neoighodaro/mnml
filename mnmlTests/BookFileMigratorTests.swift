//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct BookFileMigratorTests {
    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("migrator-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ name: String, in dir: URL) throws {
        try Data([0x2]).write(to: dir.appendingPathComponent(name))
    }

    private func names(in dir: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).sorted()
    }

    @Test func movesAllFilesLeavingSourceEmpty() throws {
        let local = try makeTempDir()
        let cloud = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: local)
            try? FileManager.default.removeItem(at: cloud)
        }
        try write("a.m4b", in: local)
        try write("b.m4b", in: local)

        BookFileMigrator.migrate(from: local, to: cloud)

        #expect(names(in: local) == [])
        #expect(names(in: cloud) == ["a.m4b", "b.m4b"])
    }

    @Test func isIdempotentOnRerun() throws {
        let local = try makeTempDir()
        let cloud = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: local)
            try? FileManager.default.removeItem(at: cloud)
        }
        try write("a.m4b", in: local)

        BookFileMigrator.migrate(from: local, to: cloud)
        BookFileMigrator.migrate(from: local, to: cloud)  // re-run: no throw, no dupes

        #expect(names(in: local) == [])
        #expect(names(in: cloud) == ["a.m4b"])
    }

    @Test func existingDestinationDropsLocalCopy() throws {
        let local = try makeTempDir()
        let cloud = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: local)
            try? FileManager.default.removeItem(at: cloud)
        }
        try write("a.m4b", in: local)
        try write("a.m4b", in: cloud)  // same name in both

        BookFileMigrator.migrate(from: local, to: cloud)

        #expect(names(in: local) == [])  // local duplicate removed
        #expect(names(in: cloud) == ["a.m4b"])  // destination untouched
    }

    @Test func partialDestinationDoesNotDestroyLocalCopy() throws {
        let local = try makeTempDir()
        let cloud = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: local)
            try? FileManager.default.removeItem(at: cloud)
        }
        // Local original is complete; a previous interrupted run left a smaller stub at dest.
        try Data([0x1, 0x2, 0x3, 0x4]).write(to: local.appendingPathComponent("a.m4b"))
        try Data([0x1]).write(to: cloud.appendingPathComponent("a.m4b"))

        BookFileMigrator.migrate(from: local, to: cloud)

        #expect(names(in: local) == [])  // local moved over the stub, nothing lost
        let destSize =
            (try? cloud.appendingPathComponent("a.m4b")
            .resourceValues(forKeys: [.fileSizeKey]))?
            .fileSize
        #expect(destSize == 4)  // destination is now the complete copy
    }
}
