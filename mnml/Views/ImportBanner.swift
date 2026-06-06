//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// Floating, non-interactive progress card shown while an import runs.
/// Indeterminate spinner + "Importing…" for a single file; spinner + count +
/// progress bar ("Importing 3 of 12…") for a folder batch.
struct ImportBanner: View {
    let progress: ImportProgress

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(Theme.accent)
            VStack(alignment: .leading, spacing: 6) {
                Text(progress.label)
                    .font(Typography.body(14, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if let fraction = progress.fraction {
                    ProgressBar(fraction: fraction)
                        .frame(maxWidth: 180, maxHeight: 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .allowsHitTesting(false)
    }
}
