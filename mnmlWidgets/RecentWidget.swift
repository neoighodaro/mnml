//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import SwiftUI
import WidgetKit

nonisolated struct RecentEntry: TimelineEntry {
    let date: Date
    let snapshot: RecentSnapshot
    let artwork: Data?
}

nonisolated struct RecentProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: .now, snapshot: .empty, artwork: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        // One entry; refreshes are driven by the app's reloadTimelines calls.
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> RecentEntry {
        RecentEntry(date: .now, snapshot: store.read(), artwork: store.readArtworkData())
    }
}

struct RecentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetConstants.recentKind, provider: RecentProvider()) { entry in
            RecentWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    RecentBackground(tint: entry.snapshot.tint)
                }
        }
        .configurationDisplayName("Recent")
        .description("Resume your most recent audiobook.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()  // we apply our own explicit 16pt inset in the view
    }
}

/// The container background gradient. A separate view so it can read the widget's
/// `colorScheme` from `@Environment` — required for the gradient to switch with
/// appearance (see `RecentGradient.gradient(for:scheme:)`).
private struct RecentBackground: View {
    @Environment(\.colorScheme) private var scheme
    let tint: String

    var body: some View {
        RecentGradient.gradient(for: tint, scheme: scheme)
    }
}
