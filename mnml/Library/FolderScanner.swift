//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Finds `.m4b` files inside a picked folder, up to two levels deep.
/// Level 1 = files directly in the folder. Level 2 = files inside the
/// folder's immediate subfolders. Anything deeper is ignored.
/// The caller is responsible for holding security-scoped access to `folderURL`.
///
/// Pure file-system utility with no main-actor state, so it is `nonisolated`:
/// under the target's default-MainActor isolation this lets the static helpers
/// (e.g. `isImportableAudiobook`) be used as plain function values like
/// `.filter(isImportableAudiobook)`.
nonisolated enum FolderScanner {
    /// Extensions accepted as importable audiobooks. `.m4a` and `.m4b` are the
    /// same MPEG-4 container, so both are imported (and always stored on disk as
    /// `.m4b` by `M4BImporter.place`). Single source of truth for both the folder
    /// scanner and the file picker (`LibraryView.fileImportTypes`).
    static let audiobookExtensions: Set<String> = ["m4b", "m4a"]

    static func findM4Bs(in folderURL: URL) -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []

        let top = contents(of: folderURL, fm: fm)
        for url in top {
            if isImportableAudiobook(url) {
                results.append(url)
            } else if isDirectory(url) {
                for child in contents(of: url, fm: fm) where isImportableAudiobook(child) {
                    results.append(child)
                }
            }
        }
        return results.sorted { $0.path < $1.path }
    }

    /// Finds `.m4b` files directly inside `folderURL` (no subfolder descent).
    /// Used by the Inbox auto-import scan. Hidden files are skipped; results
    /// are sorted by path for deterministic ordering.
    static func findTopLevelM4Bs(in folderURL: URL) -> [URL] {
        contents(of: folderURL, fm: .default)
            .filter(isImportableAudiobook)
            .sorted { $0.path < $1.path }
    }

    /// Finds importable `.m4b` files directly inside `folderURL`, INCLUDING
    /// not-yet-downloaded iCloud placeholders. An undownloaded ubiquitous file
    /// `dune.m4b` exists on disk as the hidden placeholder `.dune.m4b.icloud`;
    /// this maps such placeholders back to the real `dune.m4b` URL so the caller
    /// can request a download and import it. Non-audiobook entries are ignored.
    /// A name present as both a real file and a placeholder collapses to one URL.
    /// Results are sorted by path for deterministic ordering. Top level only —
    /// subfolders are not descended.
    static func findTopLevelM4BsIncludingCloud(in folderURL: URL) -> [URL] {
        // No `.skipsHiddenFiles`: placeholders are hidden dotfiles we must see.
        let entries =
            (try? FileManager.default.contentsOfDirectory(
                at: folderURL, includingPropertiesForKeys: nil, options: [])) ?? []
        var seen = Set<String>()
        var results: [URL] = []
        for entry in entries {
            guard let real = realAudiobookURL(for: entry, in: folderURL) else { continue }
            if seen.insert(real.path).inserted { results.append(real) }
        }
        return results.sorted { $0.path < $1.path }
    }

    /// Maps a directory entry to the real audiobook URL it represents, or nil if
    /// it isn't an audiobook. Handles a plain `name.m4b`/`name.m4a` and the iCloud
    /// placeholder form `.name.m4b.icloud` (leading dot + `.icloud` suffix stripped).
    static func realAudiobookURL(for entry: URL, in dir: URL) -> URL? {
        let name = entry.lastPathComponent
        if name.lowercased().hasSuffix(".icloud") {
            let withoutSuffix = String(name.dropLast(".icloud".count))  // ".dune.m4a"
            let realName =
                withoutSuffix.hasPrefix(".") ? String(withoutSuffix.dropFirst()) : withoutSuffix
            let ext = URL(fileURLWithPath: realName).pathExtension.lowercased()
            guard audiobookExtensions.contains(ext) else { return nil }
            return dir.appendingPathComponent(realName)
        }
        return isImportableAudiobook(entry) ? entry : nil
    }

    private static func contents(of dir: URL, fm: FileManager) -> [URL] {
        (try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])) ?? []
    }

    private static func isImportableAudiobook(_ url: URL) -> Bool {
        audiobookExtensions.contains(url.pathExtension.lowercased())
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
