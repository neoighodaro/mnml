//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct AppLanguageTests {
    @Test func rawValuesAreLocaleCodes() {
        #expect(AppLanguage.en.rawValue == "en")
        #expect(AppLanguage.de.rawValue == "de")
    }

    @Test func displayNamesAreNative() {
        #expect(AppLanguage.en.displayName == "English")
        #expect(AppLanguage.de.displayName == "Deutsch")
    }

    @Test func roundTripsAndEnumeratesAll() {
        #expect(AppLanguage(rawValue: "de") == .de)
        #expect(AppLanguage.allCases == [.en, .de])
    }
}
