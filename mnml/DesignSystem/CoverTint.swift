//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI

/// The 6 muted cover tints from the handoff (data.jsx TINTS). Each is a bg/ink pair.
enum CoverTint {
    static let all = ["clay", "sage", "slate", "sand", "plum", "mist"]

    struct Pair {
        let bg: Color
        let ink: Color
    }

    static let pairs: [String: Pair] = [
        "clay": Pair(bg: Color(hex: 0xE4D8CD), ink: Color(hex: 0x5A4836)),
        "sage": Pair(bg: Color(hex: 0xD7DFD7), ink: Color(hex: 0x41524A)),
        "slate": Pair(bg: Color(hex: 0xD5DBE3), ink: Color(hex: 0x3A4654)),
        "sand": Pair(bg: Color(hex: 0xEAE2CF), ink: Color(hex: 0x5C5234)),
        "plum": Pair(bg: Color(hex: 0xDFD7E2), ink: Color(hex: 0x4E4156)),
        "mist": Pair(bg: Color(hex: 0xD8E1E4), ink: Color(hex: 0x3B4B51)),
    ]

    static func pair(_ name: String) -> Pair { pairs[name] ?? pairs["slate"]! }

    /// Stable, deterministic tint from a title — same title always maps to the same tint.
    static func assign(for title: String) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603  // FNV-1a offset basis
        for byte in title.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return all[Int(hash % UInt64(all.count))]
    }
}

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
