//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Testing
import UIKit

@testable import mnml

struct ArtworkImageTests {
    /// Render a solid-color square image of the given pixel size and return its PNG data.
    private func squareImageData(side: CGFloat) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        return image.pngData()!
    }

    @Test func downscalesOversizedImageToMaxEdge() throws {
        let data = squareImageData(side: 3000)
        let prepared = try #require(ArtworkImage.prepared(from: data, maxEdge: 1000))
        let ui = try #require(UIImage(data: prepared))
        // Long edge clamped to ~maxEdge (allow 1px rounding).
        #expect(max(ui.size.width, ui.size.height) <= 1001)
        // Re-encode shrinks a 3000px PNG well under 1 MB.
        #expect(prepared.count < data.count)
    }

    @Test func leavesSmallImageWithinCap() throws {
        let data = squareImageData(side: 200)
        let prepared = try #require(ArtworkImage.prepared(from: data, maxEdge: 1000))
        let ui = try #require(UIImage(data: prepared))
        #expect(max(ui.size.width, ui.size.height) <= 1000)
    }

    @Test func returnsNilForNonImageData() {
        #expect(ArtworkImage.prepared(from: Data([0x00, 0x01, 0x02]), maxEdge: 1000) == nil)
    }
}
