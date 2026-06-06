//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

@MainActor
struct CloudSyncMonitorReachabilityTests {
    @Test func unreachableForcesUnavailable() {
        let monitor = CloudSyncMonitor()
        monitor.unreachable = true
        #expect(monitor.state(for: "anything.m4b") == .unavailable)
    }

    @Test func reachableDefaultsToSynced() {
        let monitor = CloudSyncMonitor()
        #expect(monitor.state(for: "anything.m4b") == .synced)
    }
}
