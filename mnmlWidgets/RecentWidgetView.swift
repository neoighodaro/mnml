//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import AppIntents
import SwiftUI
import WidgetKit

struct RecentWidgetView: View {
    @Environment(\.colorScheme) private var scheme
    let entry: RecentEntry

    var body: some View {
        if entry.snapshot.isEmpty {
            emptyState
        } else {
            loadedState(entry.snapshot)
        }
    }

    // MARK: loaded

    private func loadedState(_ snap: RecentSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                artwork(snap)
                Spacer(minLength: 8)
                wordmark
            }
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(snap.title)
                    .font(.custom("Space Grotesk", size: 13).weight(.bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(snap.author)
                    .font(.custom("Inter", size: 12))
                    .foregroundStyle(Theme.text2)
                    .lineLimit(1)
            }
            .padding(.bottom, 10)
            pill(isPlaying: snap.isPlaying)
        }
        .padding(16)
        .widgetURL(URL(string: "\(WidgetConstants.urlScheme)://\(WidgetConstants.nowPlayingHost)"))
    }

    private func artwork(_ snap: RecentSnapshot) -> some View {
        Group {
            if let data = entry.artwork, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.text.opacity(0.12)
                    Text(snap.title.prefix(1).uppercased())
                        .font(.custom("Space Grotesk", size: 22).weight(.bold))
                        .foregroundStyle(Theme.text)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var wordmark: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("mnml")
                .font(.custom("Space Grotesk", size: 13).weight(.medium))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
            Circle().fill(Theme.text).frame(width: 3, height: 3).offset(y: -3)
        }
    }

    private func pill(isPlaying: Bool) -> some View {
        Button(intent: TogglePlaybackIntent()) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Theme.track(scheme), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: empty

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            wordmark
            Text("Nothing playing yet")
                .font(.custom("Inter", size: 12))
                .foregroundStyle(Theme.text2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .widgetURL(URL(string: "\(WidgetConstants.urlScheme)://\(WidgetConstants.libraryHost)"))
    }
}
