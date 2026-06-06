//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI

/// A single-line label that scrolls horizontally when its text is wider than the available
/// width, looping with a brief pause each cycle. When the text fits it sits static (truncating
/// only as a safety net). Honors Reduce Motion by falling back to a static, tail-truncated label.
///
/// Layout contract: the view always occupies exactly the available width and one line's height —
/// it never grows to the text's intrinsic width. The scrolling copies live in an overlay that is
/// allowed to overflow and is clipped, so a long title can't push neighboring views off-screen.
struct MarqueeText: View {
    let text: String
    var font: Font = .body
    var color: Color = .primary
    /// Letter spacing applied to the text.
    var tracking: CGFloat = 0
    /// How the text sits when it fits and doesn't need to scroll.
    var alignment: Alignment = .center
    /// Blank gap between the trailing copy and the looped-around leading copy.
    var spacing: CGFloat = 44
    /// Scroll speed in points per second.
    var velocity: Double = 30
    /// Pause before each scroll cycle begins.
    var startDelay: Double = 1.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    /// Bumped on every (re)start so a pending deferred animation can detect it's stale
    /// (e.g. the chapter changed during the start pause) and bail out.
    @State private var runToken = 0

    private var overflowing: Bool { textWidth > containerWidth + 1 }
    private var animating: Bool { overflowing && !reduceMotion }

    var body: some View {
        // The base label defines the view's size: it fills the available width and one line of
        // height, truncating rather than growing. While scrolling it's hidden (kept for sizing)
        // and the moving copies are drawn in the overlay instead.
        Text(text)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(animating ? .clear : color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: alignment)
            .overlay(alignment: .leading) {
                if animating {
                    HStack(spacing: spacing) {
                        copy
                        copy
                    }
                    .fixedSize()
                    .offset(x: offset)
                }
            }
            .clipped()
            .background(containerReader)
            .background(textMeasurer)
            .onChange(of: text) { restart() }
            .onChange(of: animating) { restart() }
            .onAppear { restart() }
    }

    private var copy: some View {
        Text(text).font(font).tracking(tracking).foregroundStyle(color)
    }

    /// Reports the available (container) width — drives the overflow test and scroll distance.
    private var containerReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { containerWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, w in containerWidth = w }
        }
    }

    /// A hidden, intrinsically-sized copy that reports the text's natural width. Placed in a
    /// background so it never influences the host's layout size.
    private var textMeasurer: some View {
        Text(text).font(font).tracking(tracking)
            .fixedSize()
            .hidden()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { textWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in textWidth = w }
                }
            )
    }

    private func restart() {
        // Snap back to the leading edge with no animation so the text is immediately visible
        // there (not mid-scroll). The looping animation is then started in a later runloop turn
        // — attaching a `repeatForever` in the same transaction as this reset makes SwiftUI start
        // it mid-cycle, which looked like the text scrolling in from off-screen.
        runToken += 1
        let token = runToken
        offset = 0
        guard animating else { return }
        let distance = textWidth + spacing
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            guard token == runToken, animating else { return }
            withAnimation(.linear(duration: distance / velocity).repeatForever(autoreverses: false))
            {
                offset = -distance
            }
        }
    }
}
