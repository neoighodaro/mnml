//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing

@testable import mnml

struct ModelStoreFactoryTests {
    @Test func enablesOnlyWhenOnAndAccountAvailable() {
        #expect(
            ModelStoreFactory.shouldEnableCloudKit(syncEnabled: true, accountAvailable: true)
                == true)
        #expect(
            ModelStoreFactory.shouldEnableCloudKit(syncEnabled: true, accountAvailable: false)
                == false)
        #expect(
            ModelStoreFactory.shouldEnableCloudKit(syncEnabled: false, accountAvailable: true)
                == false)
        #expect(
            ModelStoreFactory.shouldEnableCloudKit(syncEnabled: false, accountAvailable: false)
                == false)
    }
}
