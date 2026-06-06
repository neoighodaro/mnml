//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Whether an iCloud account is currently available on this device. Used to
/// decide if CloudKit mirroring can be turned on, and to explain a disabled
/// state in Settings. `ubiquityIdentityToken` is non-nil exactly when the user
/// is signed into iCloud.
enum ICloudAccount {
    static var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}
