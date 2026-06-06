//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct SyncRowStateTests {
    @Test func availableMapsToActiveOrOff() {
        #expect(SyncRowState.resolve(prefEnabled: true, availability: .available) == .active)
        #expect(SyncRowState.resolve(prefEnabled: false, availability: .available) == .off)
    }

    @Test func enabledButNoUsableAccountIsPaused() {
        #expect(SyncRowState.resolve(prefEnabled: true, availability: .noAccount) == .paused)
        #expect(SyncRowState.resolve(prefEnabled: true, availability: .restricted) == .paused)
        #expect(SyncRowState.resolve(prefEnabled: true, availability: .unavailable) == .paused)
    }

    @Test func disabledAndNoUsableAccountIsSignInPrompt() {
        #expect(SyncRowState.resolve(prefEnabled: false, availability: .noAccount) == .signInPrompt)
        #expect(
            SyncRowState.resolve(prefEnabled: false, availability: .unavailable) == .signInPrompt)
    }
}
