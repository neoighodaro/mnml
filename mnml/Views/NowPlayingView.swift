//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerEngine.self) private var engine
    let onClose: () -> Void
    @State private var showChapters = false
    @State private var dragOffset: CGFloat = 0

    private var book: Book? { engine.currentBook }
    private var isDownloading: Bool { engine.loadState == .downloading }

    private var downloadError: String? {
        if case .failed(let message) = engine.loadState { return message }
        return nil
    }

    /// Transport (scrubber, skips, chapter jumps, secondary row) is meaningless until an item
    /// is ready — disable it while downloading or after a failure. The central play button is
    /// handled separately: it spins while downloading and stays tappable to retry on failure.
    private var transportDisabled: Bool { isDownloading || downloadError != nil }

    /// Interactive swipe-down to minimize. `.fullScreenCover` has no built-in dismiss
    /// gesture, so the view tracks the finger and dismisses past a threshold, else snaps back.
    /// Plain `.gesture` (not high-priority) lets the Scrubber's own drag win when touched.
    private var dismissDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 { dragOffset = value.translation.height }
            }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 300 {
                    onClose()
                }
                // Always settle the offset back to 0 — even when dismissing. The ZStack keeps
                // this view (and its @State) alive through the close transition, so leaving a
                // non-zero offset lets a quick re-open reuse the stale value, re-appearing the
                // player shifted down (the "opens to ~80%, top strip showing" bug). On dismiss
                // the .move transition still carries the view off-screen; this offset just eases
                // out to 0 underneath it, so there's no visual hitch.
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragOffset = 0 }
            }
    }

    var body: some View {
        if let book {
            content(book)
        } else {
            Color.clear.onAppear(perform: onClose)
        }
    }

    private func content(_ book: Book) -> some View {
        // Progress UI is chapter-relative: the scrubber and time labels track the current
        // chapter, not the whole book. `locate` gives the offset into the chapter (`into`)
        // and its absolute start (`base`); seeking maps back to a book position via `base`.
        let loc = BookMath.locate(progress: engine.currentTime, durations: book.chapterDurations)
        let chapterDuration = book.chapterDurations[safe: loc.index] ?? engine.duration
        let chapterTitle = book.orderedChapters[safe: engine.currentChapterIndex]?.title ?? ""
        return GeometryReader { geo in
            // Size the cover to the device: full size on standard/large iPhones, trimmed on
            // short screens (SE-class) where the transport controls need the vertical room.
            let small = geo.size.height < 700
            let coverSize: CGFloat = small ? 240 : 320
            let coverRadius: CGFloat = small ? 18 : 20
            VStack(spacing: 0) {
                topBar

                Spacer()

                ZStack {
                    ArtworkGlow(artworkData: book.artworkData, size: coverSize, radius: coverRadius)
                    CoverView(
                        title: book.title, tint: book.tint, artworkData: book.artworkData,
                        size: coverSize, radius: coverRadius
                    )
                    .shadow(
                        color: .black.opacity(ArtworkGlow.isEnabled ? 0.16 : 0.28),
                        radius: ArtworkGlow.isEnabled ? 16 : 28, y: 14)
                }
                .scaleEffect(engine.isPlaying ? 1.1 : 0.94)
                .animation(.bouncy(duration: 0.35, extraBounce: 0.4), value: engine.isPlaying)

                VStack(spacing: 8) {
                    Text(book.title).font(Typography.playerH1).tracking(-0.9)
                        .foregroundStyle(Theme.text).multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.8)

                    if isDownloading {
                        Text(L.string("Downloading…")).font(Typography.body(14))
                            .foregroundStyle(Theme.text2)
                    } else if let downloadError {
                        Text(downloadError).font(Typography.body(14))
                            .foregroundStyle(Theme.text2).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        MarqueeText(
                            text: chapterTitle, font: Typography.body(14), color: Theme.text2)
                    }
                }
                .padding(.top, 40).padding(.horizontal)
                Spacer()
                controls(
                    base: loc.base, into: loc.into, chapterDuration: chapterDuration,
                    chapterIndex: loc.index, chapterCount: book.chapterDurations.count)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
        .offset(y: dragOffset)
        .gesture(dismissDrag)
        .sheet(isPresented: $showChapters) {
            ChaptersSheet(book: book, currentIndex: engine.currentChapterIndex) { idx in
                engine.seekToChapter(idx)
                engine.play()
                showChapters = false
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap()
                onClose()
            } label: {
                Image(systemName: "chevron.down").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.text2).frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, Theme.topSafe - 38)
        .frame(height: 44)
    }

    private func controls(
        base: Double, into: Double, chapterDuration: Double,
        chapterIndex: Int, chapterCount: Int
    ) -> some View {
        VStack(spacing: 0) {
            Group {
                Scrubber(fraction: chapterDuration > 0 ? into / chapterDuration : 0) { frac in
                    engine.seek(to: base + frac * chapterDuration)
                }
                HStack {
                    Text(TimeFormat.fmt(into))
                    Spacer()
                    Text("-\(TimeFormat.fmt(chapterDuration - into))")
                }
                .font(Typography.times).monospacedDigit().foregroundStyle(Theme.text3)
            }
            .disabled(transportDisabled)
            .opacity(transportDisabled ? 0.4 : 1)

            HStack(spacing: 16) {
                transportButton("backward.end.fill", size: 20, frame: 46) {
                    engine.previousChapter()
                }
                .disabled(transportDisabled).opacity(transportDisabled ? 0.3 : 1)
                transportButton("gobackward.30", size: 28, frame: 52) { engine.skipBack() }
                    .disabled(transportDisabled).opacity(transportDisabled ? 0.3 : 1)
                Button {
                    Haptics.tap(.medium)
                    engine.toggle()
                } label: {
                    ZStack {
                        if isDownloading {
                            ProgressView().tint(.white).scaleEffect(1.2)
                        } else {
                            let glyph = engine.isPlaying ? "pause.fill" : "play.fill"
                            Image(systemName: glyph)
                                .font(.system(size: 64)).foregroundStyle(Theme.accent.opacity(0.95))
                                .contentTransition(.symbolEffect(.replace))
                                .animation(.snappy(duration: 0.01), value: engine.isPlaying)
                                .overlay {
                                    LevelFillEffect(
                                        level: { engine.currentAudioRMS() },
                                        isPlaying: engine.isPlaying,
                                        color: Theme.accentDeep
                                    )
                                    .mask { Image(systemName: glyph).font(.system(size: 64)) }
                                    .allowsHitTesting(false)
                                }
                        }
                    }
                    .scaleEffect(engine.isPlaying ? 1.04 : 1.0)
                    .animation(.bouncy(duration: 0.3, extraBounce: 0.45), value: engine.isPlaying)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .disabled(isDownloading)

                transportButton("goforward.30", size: 28, frame: 52) { engine.skipForward() }
                    .disabled(transportDisabled)
                    .opacity(transportDisabled ? 0.3 : 1)

                transportButton("forward.end.fill", size: 20, frame: 46) { engine.nextChapter() }
                    .disabled(transportDisabled || chapterIndex >= chapterCount - 1)
                    .opacity(transportDisabled || chapterIndex >= chapterCount - 1 ? 0.3 : 1)
            }
            .padding(.top, 18)

            secondaryRow
                .padding(.top, 48)
                .disabled(transportDisabled)
                .opacity(transportDisabled ? 0.4 : 1)
        }
        .padding(.horizontal, Theme.playerPadding)
        .padding(.bottom, Theme.botSafe + 22)
    }

    private var secondaryRow: some View {
        HStack {
            SpeedMenuButton(engine: engine)
                .frame(minWidth: 52, alignment: .leading)
            Spacer()

            SleepMenuButton(engine: engine)

            Spacer()

            Button {
                Haptics.tap()
                showChapters = true
            } label: {
                Image(systemName: "list.bullet").font(.system(size: 18))
                    .foregroundStyle(Theme.text2)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 52, alignment: .center)

            Spacer()

            AirPlayButton()
                .frame(width: 24, height: 24)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    private func transportButton(
        _ symbol: String, size: CGFloat, frame: CGFloat = 56, action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(Theme.accent.opacity(0.95)).frame(width: frame, height: frame)
        }
        .buttonStyle(.plain)
    }
}

/// Colored ambient "shadow" for the hero cover: a heavily blurred, enlarged copy of the
/// artwork sits behind it, so the cover lifts off the background on a soft cloud of its own
/// colors. Renders nothing for typographic covers (no artwork) or when the flag is off.
private struct ArtworkGlow: View {
    /// Halo presets. Switch the active one with `Self.preset`.
    /// - `bold`: the original wide, diffuse color cloud.
    /// - `minimal`: a tighter halo that hugs the cover edge.
    /// - `none`: no color glow — only the plain dark drop shadow remains.
    enum Preset {
        case bold, minimal, none

        /// How far the halo diffuses outward. Lower = a tighter, less wide glow.
        var blurRadius: CGFloat {
            switch self {
            case .bold: return 44
            case .minimal: return 26
            case .none: return 0
            }
        }
        /// How far past the cover edge the cloud starts. Closer to 1 keeps it from spreading wide.
        var scale: CGFloat {
            switch self {
            case .bold: return 1.06
            case .minimal: return 1.02
            case .none: return 1
            }
        }
        /// Overall halo strength.
        var opacity: CGFloat {
            switch self {
            case .bold: return 0.6
            case .minimal: return 0.45
            case .none: return 0
            }
        }
    }

    /// Active halo preset. Change this one line to switch looks.
    static let preset: Preset = .bold

    static var isEnabled: Bool { preset != .none }

    let artworkData: Data?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        if Self.isEnabled, let data = artworkData, let ui = UIImage(data: data) {
            let preset = Self.preset
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .saturation(1.4)  // push the palette so the halo actually reads as color
                .blur(radius: preset.blurRadius)  // diffuse into a soft cloud that bleeds past the cover
                .scaleEffect(preset.scale)  // a touch larger than the cover so color shows at every edge
                .opacity(preset.opacity)
                .offset(y: 12)  // bias downward so the cloud still feels like a shadow
                .allowsHitTesting(false)
        }
    }
}

/// Playback-speed control. Extracted into its own view so it observes only the current
/// book's `speed` — never the engine's per-tick `currentTime`. That keeps SwiftUI from
/// re-evaluating it on every progress tick, which otherwise made the open menu flicker.
private struct SpeedMenuButton: View {
    let engine: PlayerEngine

    var body: some View {
        let speed = engine.currentBook?.speed ?? 1
        Menu {
            // No haptic in this builder: a Menu's content is re-evaluated on every render, so a
            // tap() here would fire continuously. The picker's set: gives the selection haptic.
            Picker(
                "Speed",
                selection: Binding(
                    get: { engine.currentBook?.speed ?? 1 },
                    set: {
                        Haptics.tap()
                        engine.setSpeed($0)
                    }
                )
            ) {
                ForEach(PlaybackMath.speeds, id: \.self) { speed in
                    Text(PlaybackMath.speedLabel(speed)).tag(speed)
                }
            }
        } label: {
            Text(PlaybackMath.speedLabel(speed)).font(Typography.speedValue)
                .monospacedDigit().foregroundStyle(Theme.text2)
        }
        .buttonStyle(.plain)
        // Haptic the instant the menu opens. Fired from a zero-distance drag's onChanged
        // (touch-down) rather than a TapGesture's onEnded: the menu can swallow the touch-up,
        // so an end-based tap often never lands. onChanged fires once for a stationary tap.
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in Haptics.tap() })
    }
}

/// Sleep-timer control. Extracted like `SpeedMenuButton` so it observes only the sleep
/// timer's own state (which changes on set/expire, not every tick), preventing the open
/// menu from flickering on each progress tick.
private struct SleepMenuButton: View {
    let engine: PlayerEngine

    var body: some View {
        let timer = engine.sleepTimer

        Menu {
            Picker(
                "Sleep Timer",
                selection: Binding(
                    get: { timer.minutes },
                    set: {
                        Haptics.tap()
                        timer.set(minutes: $0)
                    }
                )
            ) {
                Text("Off").tag(0)
                Text("15 min").tag(15)
                Text("30 min").tag(30)
                Text("45 min").tag(45)
                Text("60 min").tag(60)
                Text("90 min").tag(90)
                Text("120 min").tag(120)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "moon").font(.system(size: 18))
                if let label = timer.label {
                    Text(label).font(Typography.body(12.5, weight: .medium)).monospacedDigit()
                }
            }
            .foregroundStyle(timer.label != nil ? Theme.accent : Theme.text2)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in Haptics.tap() })
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
