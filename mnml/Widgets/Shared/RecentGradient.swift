//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI

/// Builds the widget background gradient from a `CoverTint` key, reacting to appearance:
/// dark mode uses the tint's dark `ink` (top) over a darker stop; light mode uses the
/// pastel `bg` over a slightly darker stop. The caller passes the current `ColorScheme`
/// (from `@Environment`) — see `gradient(for:scheme:)` for why we don't use a dynamic
/// `UIColor` here. Text/button colors come from `Theme`.
nonisolated enum RecentGradient {
    /// Tint hex values mirrored from `CoverTint.pairs` so the widget needs no `Color`→hex
    /// round-trip. `inkHex` is the dark-mode field, `bgHex` the light-mode field. Keep in
    /// sync with CoverTint.
    private static let inkHex: [String: UInt32] = [
        "clay": 0x5A4836, "sage": 0x41524A, "slate": 0x3A4654,
        "sand": 0x5C5234, "plum": 0x4E4156, "mist": 0x3B4B51,
    ]
    private static let bgHex: [String: UInt32] = [
        "clay": 0xE4D8CD, "sage": 0xD7DFD7, "slate": 0xD5DBE3,
        "sand": 0xEAE2CF, "plum": 0xDFD7E2, "mist": 0xD8E1E4,
    ]

    /// Dark-mode top stop (the tint's ink).
    static func topHex(for tint: String) -> UInt32 {
        inkHex[tint] ?? inkHex["slate"]!
    }

    /// Dark-mode bottom stop: ink darkened ~35%.
    static func bottomHex(for tint: String) -> UInt32 {
        darken(topHex(for: tint), 0.65)
    }

    /// Light-mode top stop (the tint's pastel bg).
    static func lightTopHex(for tint: String) -> UInt32 {
        bgHex[tint] ?? bgHex["slate"]!
    }

    /// Light-mode bottom stop: bg darkened slightly for a soft gradient.
    static func lightBottomHex(for tint: String) -> UInt32 {
        darken(lightTopHex(for: tint), 0.90)
    }

    /// Scale each channel by `factor`.
    private static func darken(_ h: UInt32, _ factor: Double) -> UInt32 {
        let r = UInt32(Double((h >> 16) & 0xFF) * factor)
        let g = UInt32(Double((h >> 8) & 0xFF) * factor)
        let b = UInt32(Double(h & 0xFF) * factor)
        return (r << 16) | (g << 8) | b
    }

    /// The gradient for the given appearance. Takes an explicit `scheme` and resolves to
    /// plain (non-dynamic) `Color(hex:)` stops on purpose: a `LinearGradient` flattens its
    /// stops to `CGColor`, which has no dynamic-trait behavior, so a `UIColor`-backed
    /// dynamic color would get stuck in whatever appearance it first rendered in. Driving
    /// off `@Environment(\.colorScheme)` (read at the call site) is what makes it switch.
    static func gradient(for tint: String, scheme: ColorScheme) -> LinearGradient {
        let (top, bottom) =
            scheme == .dark
            ? (topHex(for: tint), bottomHex(for: tint))
            : (lightTopHex(for: tint), lightBottomHex(for: tint))
        return LinearGradient(
            colors: [Color(hex: top), Color(hex: bottom)],
            startPoint: .top, endPoint: .bottom)
    }
}
