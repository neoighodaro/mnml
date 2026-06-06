//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Localization helper for strings resolved in code (not inside a SwiftUI `Text`).
///
/// SwiftUI `Text` literals re-resolve against `\.locale` automatically, but
/// `String(localized:)` ignores the SwiftUI environment. This resolves against the
/// currently-selected language's `.lproj` explicitly. Shares the `appLanguage`
/// `UserDefaults` key with `@AppStorage`, so it tracks the user's choice.
enum L {
    static let languageKey = "appLanguage"

    static func string(_ key: String.LocalizationValue) -> String {
        let code = UserDefaults.standard.string(forKey: languageKey) ?? "en"
        let bundle =
            Bundle.main.path(forResource: code, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        return String(localized: key, bundle: bundle)
    }
}
