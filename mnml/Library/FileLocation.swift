//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import Foundation

/// Decides which `Books/` directory the app uses for this launch: the iCloud Drive
/// ubiquity container (when sync is on, an account is present, and the container
/// resolved) or local `Documents/`. Pure — all inputs are passed in, so it is
/// unit-tested without touching real iCloud. The "should we use cloud" rule is
/// shared with the records layer via `ModelStoreFactory.shouldEnableCloudKit`.
enum FileLocation {
    static func booksDirectory(
        syncEnabled: Bool,
        accountAvailable: Bool,
        ubiquityDocuments: URL?,
        localDocuments: URL
    ) -> URL {
        let base: URL
        if ModelStoreFactory.shouldEnableCloudKit(
            syncEnabled: syncEnabled,
            accountAvailable: accountAvailable),
            let cloud = ubiquityDocuments
        {
            base = cloud
        } else {
            base = localDocuments
        }
        return base.appendingPathComponent("Books", isDirectory: true)
    }
}
