//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// Confirmation-dialog copy for deleting a book, phrased by sync mode: with sync on,
/// deletion propagates to every device; in local-only mode it's just this device's
/// file. Centralized so the library grid, Continue Listening, and the detail screen
/// stay in lockstep. Returns `LocalizedStringKey` so the string-catalog keys are
/// identical to the inline literals these replaced — localization is unaffected.
enum DeleteCopy {
    static func single(_ title: String, syncEnabled: Bool) -> LocalizedStringKey {
        syncEnabled
            ? "“\(title)” will be removed from all your devices. This can't be undone."
            : "“\(title)” and its downloaded file will be deleted. This can't be undone."
    }

    static func multiple(syncEnabled: Bool) -> LocalizedStringKey {
        syncEnabled
            ? "The selected books will be removed from all your devices. This can't be undone."
            : "The selected books and their downloaded files will be deleted. This can't be undone."
    }
}
