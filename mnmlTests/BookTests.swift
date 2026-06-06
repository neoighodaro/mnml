//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing

@testable import mnml

struct BookTests {
    @Test func designatedInitStoresOriginalExtension() {
        let book = Book(
            title: "Title", author: "Author", narrator: nil,
            fileName: "abc.m4b", artworkData: nil, tint: "",
            durationSeconds: 100, dateAdded: .now,
            originalExtension: "m4a")
        #expect(book.originalExtension == "m4a")
    }

    @Test func memberwiseInitLeavesOriginalExtensionNil() {
        #expect(Book().originalExtension == nil)
    }
}
