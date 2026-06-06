//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

struct ChaptersSheet: View {
    let book: Book
    let currentIndex: Int
    let onPick: (Int) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chapters").font(Typography.display(18)).tracking(-0.5)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(book.orderedChapters.count)").eyebrowStyle()
            }
            .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(book.orderedChapters.enumerated()), id: \.offset) { i, ch in
                        let current = i == currentIndex
                        Button {
                            Haptics.tap()
                            onPick(i)
                        } label: {
                            HStack(spacing: 14) {
                                Text(String(format: "%02d", i + 1)).font(Typography.chapterNum)
                                    .monospacedDigit()
                                    .foregroundStyle(current ? Theme.accent : Theme.text3)
                                    .fontWeight(current ? .semibold : .regular)
                                    .frame(width: 18, alignment: .leading)
                                // Only the playing chapter scrolls long titles; the rest stay
                                // single-line truncated so the list doesn't become a wall of motion.
                                if current {
                                    MarqueeText(
                                        text: ch.title,
                                        font: Typography.body(15, weight: .medium),
                                        color: Theme.accent, tracking: -0.15, alignment: .leading)
                                } else {
                                    Text(ch.title).font(Typography.chapterTitle).tracking(-0.15)
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1).truncationMode(.tail)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if current {
                                    Circle().fill(Theme.accent).frame(width: 6, height: 6)
                                } else {
                                    Text(TimeFormat.fmtLong(ch.duration))
                                        .font(Typography.body(12.5))
                                        .monospacedDigit().foregroundStyle(Theme.text3)
                                }
                            }
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(Theme.hairline(scheme)).frame(height: 0.5) }
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, Theme.botSafe + 16)
            }
        }
        .background(Theme.bg)
        .presentationDetents([.fraction(0.76)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(22)
    }
}
