//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import CloudKit
import Testing

@testable import mnml

struct ICloudAccountMonitorTests {
    @Test func noTokenIsNoAccountRegardlessOfStatus() {
        #expect(ICloudAccountMonitor.derive(hasToken: false, ckStatus: .available) == .noAccount)
        #expect(ICloudAccountMonitor.derive(hasToken: false, ckStatus: .noAccount) == .noAccount)
    }

    @Test func tokenWithStableStatusMapsThrough() {
        #expect(ICloudAccountMonitor.derive(hasToken: true, ckStatus: .available) == .available)
        #expect(ICloudAccountMonitor.derive(hasToken: true, ckStatus: .restricted) == .restricted)
        #expect(ICloudAccountMonitor.derive(hasToken: true, ckStatus: .noAccount) == .noAccount)
    }

    @Test func transientStatusesAreUnavailable() {
        #expect(
            ICloudAccountMonitor.derive(hasToken: true, ckStatus: .temporarilyUnavailable)
                == .unavailable)
        #expect(
            ICloudAccountMonitor.derive(hasToken: true, ckStatus: .couldNotDetermine)
                == .unavailable)
    }
}
