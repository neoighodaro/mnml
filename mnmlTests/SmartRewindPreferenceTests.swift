//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

struct SmartRewindPreferenceTests {
    private func freshDefaults(suite: String = #function) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsToEnabledWhenUnset() {
        let pref = SmartRewindPreference(defaults: freshDefaults())
        #expect(pref.isEnabled == true)
    }

    @Test func persistsDisabled() {
        let defaults = freshDefaults()
        let pref = SmartRewindPreference(defaults: defaults)
        pref.isEnabled = false
        #expect(SmartRewindPreference(defaults: defaults).isEnabled == false)
    }

    @Test func persistsReEnabled() {
        let defaults = freshDefaults()
        let pref = SmartRewindPreference(defaults: defaults)
        pref.isEnabled = false
        pref.isEnabled = true
        #expect(SmartRewindPreference(defaults: defaults).isEnabled == true)
    }
}
