//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation
import Testing

@testable import mnml

struct FileLocationTests {
    private let local = URL(fileURLWithPath: "/tmp/local-docs", isDirectory: true)
    private let cloud = URL(fileURLWithPath: "/tmp/cloud-docs", isDirectory: true)

    @Test func usesCloudWhenSyncOnAccountOnAndContainerPresent() {
        let dir = FileLocation.booksDirectory(
            syncEnabled: true, accountAvailable: true,
            ubiquityDocuments: cloud, localDocuments: local)
        #expect(dir == cloud.appendingPathComponent("Books", isDirectory: true))
    }

    @Test func fallsBackToLocalWhenContainerMissing() {
        let dir = FileLocation.booksDirectory(
            syncEnabled: true, accountAvailable: true,
            ubiquityDocuments: nil, localDocuments: local)
        #expect(dir == local.appendingPathComponent("Books", isDirectory: true))
    }

    @Test func usesLocalWhenSyncOff() {
        let dir = FileLocation.booksDirectory(
            syncEnabled: false, accountAvailable: true,
            ubiquityDocuments: cloud, localDocuments: local)
        #expect(dir == local.appendingPathComponent("Books", isDirectory: true))
    }

    @Test func usesLocalWhenNoAccount() {
        let dir = FileLocation.booksDirectory(
            syncEnabled: true, accountAvailable: false,
            ubiquityDocuments: cloud, localDocuments: local)
        #expect(dir == local.appendingPathComponent("Books", isDirectory: true))
    }
}
