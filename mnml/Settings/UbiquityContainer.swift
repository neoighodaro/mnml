//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import os

/// The app's iCloud Drive ubiquity container. `documentsURL()` returns the
/// container's `Documents/` directory — the user-visible "mnml" folder under
/// iCloud Drive (see `NSUbiquitousContainers` in Info.plist) — or `nil` when
/// iCloud is unavailable.
///
/// IMPORTANT: call `documentsURL()` OFF the main thread. The first call can block
/// while the container is provisioned.
nonisolated enum UbiquityContainer {
    static let identifier = "iCloud.com.tapsharp.mnml"

    private static let log = Logger(subsystem: "com.tapsharp.mnml", category: "iCloud")

    static func documentsURL() -> URL? {
        guard
            let container = FileManager.default
                .url(forUbiquityContainerIdentifier: identifier)
        else {
            log.warning(
                "Ubiquity container unavailable (\(identifier, privacy: .public)); falling back to local storage"
            )
            return nil
        }
        let docs = container.appendingPathComponent("Documents", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        } catch {
            log.error(
                "Failed to create iCloud Documents directory: \(error.localizedDescription, privacy: .public)"
            )
        }
        return docs
    }
}
