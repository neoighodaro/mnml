//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI

/// Color tokens from the handoff (README "Design Tokens"). Light + dark resolved
/// automatically via the asset-free dynamic colors below.
enum Theme {
    // accent (mariner) — light #3B6FD4, brighter in dark
    static let accent = Color.dynamic(light: 0x3B6FD4, dark: 0x4E84E8)
    // accentDeep — accent darkened ~18%, the liquid fill behind the play glyph.
    static let accentDeep = Color.dynamic(light: 0x305BAE, dark: 0x406CBE)

    static let bg = Color.dynamic(light: 0xFCFCFD, dark: 0x161618)
    static let text = Color.dynamic(light: 0x1A1D21, dark: 0xF2F2F3)
    static let text2 = Color.dynamic(light: 0x60646C, dark: 0x9DA0A8)
    static let text3 = Color.dynamic(light: 0x9A9DA6, dark: 0x6B6E76)

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.07)
    }
    static func track(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
    }

    // spacing / radii
    static let screenPadding: CGFloat = 22
    static let playerPadding: CGFloat = 34
    static let topSafe: CGFloat = 60
    static let botSafe: CGFloat = 34
    static let miniPlayerInset: CGFloat = 96
}

extension Color {
    /// A color that resolves differently in light vs dark. `nonisolated` so it can be
    /// called from nonisolated widget code (e.g. `RecentGradient`).
    nonisolated static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(
            UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
            })
    }
}
