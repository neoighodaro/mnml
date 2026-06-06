//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

struct CloudSyncPreferenceTests {
    private func freshDefaults(suite: String = #function) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsToDisabled() {
        let pref = CloudSyncPreference(defaults: freshDefaults())
        #expect(pref.isEnabled == false)
    }

    @Test func persistsEnabled() {
        let defaults = freshDefaults()
        var pref = CloudSyncPreference(defaults: defaults)
        pref.isEnabled = true
        #expect(CloudSyncPreference(defaults: defaults).isEnabled == true)
    }
}
