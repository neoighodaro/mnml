//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI
import Testing

@testable import mnml

struct AppearanceTests {
    @Test func systemMapsToNilColorScheme() {
        #expect(Appearance.system.colorScheme == nil)
    }

    @Test func lightAndDarkMapToColorSchemes() {
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
    }

    @Test func rawValuesRoundTrip() {
        #expect(Appearance(rawValue: "system") == .system)
        #expect(Appearance(rawValue: "light") == .light)
        #expect(Appearance(rawValue: "dark") == .dark)
        #expect(Appearance.allCases.count == 3)
    }
}
