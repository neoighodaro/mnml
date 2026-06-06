//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// The single source of truth for whether the user has turned on iCloud Sync.
/// Stored in UserDefaults under `storageKey`; the same key backs the Settings
/// toggle's `@AppStorage`. Read at launch by `ModelStoreFactory` to decide
/// whether to enable CloudKit mirroring.
struct CloudSyncPreference {
    static let storageKey = "iCloudSyncEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.storageKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.storageKey) }
    }
}
