//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import UIKit

/// Prepares user-picked cover images for storage: downscales to a sane long-edge cap
/// and JPEG-encodes so `Book.artworkData` (CloudKit external storage) stays small,
/// matching the modest size of import-extracted artwork.
enum ArtworkImage {
    /// Returns downscaled JPEG data, or nil if `data` isn't a decodable image.
    static func prepared(from data: Data, maxEdge: CGFloat = 1000, quality: CGFloat = 0.8) -> Data?
    {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1  // target is already in pixels
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
