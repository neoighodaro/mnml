//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData

@Model
final class Chapter {
    var title: String = ""
    var startTime: Double = 0
    var duration: Double = 0
    var order: Int = 0
    var book: Book?

    init(title: String, startTime: Double, duration: Double, order: Int) {
        self.title = title
        self.startTime = startTime
        self.duration = duration
        self.order = order
    }
}
