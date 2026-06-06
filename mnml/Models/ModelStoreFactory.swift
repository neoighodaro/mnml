//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData

/// Builds the app's `ModelContainer`, turning on CloudKit mirroring only when
/// the user enabled iCloud Sync AND an iCloud account is available. The same
/// on-disk store is used either way — enabling sync just starts mirroring it;
/// disabling stops mirroring without moving data.
enum ModelStoreFactory {
    /// CloudKit container identifier (must match the entitlement). Shares the single
    /// source of truth with the files layer so the records and files containers can't drift.
    static let cloudContainerID = UbiquityContainer.identifier

    /// Pure decision used at launch. Kept separate so it can be unit-tested
    /// without touching entitlements or a real account.
    static func shouldEnableCloudKit(syncEnabled: Bool, accountAvailable: Bool) -> Bool {
        syncEnabled && accountAvailable
    }

    static func makeContainer(syncEnabled: Bool, accountAvailable: Bool) throws -> ModelContainer {
        let useCloud = shouldEnableCloudKit(
            syncEnabled: syncEnabled,
            accountAvailable: accountAvailable)
        let config = ModelConfiguration(
            cloudKitDatabase: useCloud ? .private(cloudContainerID) : .none
        )
        return try ModelContainer(for: Book.self, Chapter.self, configurations: config)
    }
}
