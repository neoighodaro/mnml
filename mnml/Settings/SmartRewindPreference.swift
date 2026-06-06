//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// The single source of truth for whether Smart Rewind is on. Stored in
/// UserDefaults under `storageKey`; the same key backs the Settings control's
/// `@AppStorage`. Read by `PlayerEngine` when resuming playback.
///
/// Unlike most boolean prefs, this **defaults to `true` when unset** — Smart
/// Rewind is on out of the box. `UserDefaults.bool(forKey:)` returns `false`
/// for a missing key, so the getter special-cases the unset state. Anything
/// reading the same key via `@AppStorage` must seed the same default (see
/// `SmartRewindPreference.registerDefault`).
struct SmartRewindPreference {
    static let storageKey = "smartRewindEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get {
            // Missing key → On. Present key → its stored value.
            defaults.object(forKey: Self.storageKey) == nil
                ? true
                : defaults.bool(forKey: Self.storageKey)
        }
        nonmutating set { defaults.set(newValue, forKey: Self.storageKey) }
    }

    /// Seeds the unset default so `@AppStorage(storageKey)` (which would
    /// otherwise treat a missing Bool as `false`) agrees with `isEnabled`.
    /// Call once at app launch before any view reads the key.
    static func registerDefault(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [storageKey: true])
    }
}
