//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI

/// Book cover: embedded artwork if available, else the handoff's typographic cover
/// (title typeset on a muted tint with a thin baseline rule).
struct CoverView: View {
    let title: String
    let tint: String
    let artworkData: Data?
    var size: CGFloat = 54
    var radius: CGFloat = 7

    var body: some View {
        Group {
            if let data = artworkData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                typographic
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var typographic: some View {
        let pair = CoverTint.pair(tint)
        let pad = max(6, size * 0.13)
        let fontSize = max(7, size * 0.135)
        return ZStack(alignment: .topLeading) {
            pair.bg
            Text(title)
                .font(.custom("Space Grotesk", size: fontSize).weight(.medium))
                .tracking(-0.4)
                .foregroundStyle(pair.ink)
                .lineSpacing(fontSize * 0.14)
                .padding(pad)
            VStack {
                Spacer()
                pair.ink.opacity(0.28).frame(height: 1).padding(.horizontal, pad)
                    .padding(.bottom, pad * 0.85)
            }
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        CoverView(title: "The Overstory", tint: "sage", artworkData: nil, size: 104, radius: 11)
        CoverView(title: "Piranesi", tint: "mist", artworkData: nil, size: 54)
    }
    .padding()
}
