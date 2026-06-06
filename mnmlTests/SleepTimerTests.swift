//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct SleepTimerTests {
    @Test func labelIsNilWhenOff() {
        #expect(SleepTimer.label(for: 0) == nil)
        #expect(SleepTimer.label(for: 30) == "30m")
        #expect(SleepTimer.label(for: 120) == "120m")
    }
}
