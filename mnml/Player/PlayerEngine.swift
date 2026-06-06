//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import AVFoundation
import Foundation
import SwiftData
import UIKit
import WidgetKit

/// Where the current book is in the load → ready pipeline. `.downloading` covers
/// fetching the file from iCloud before playback can start.
enum PlayerLoadState: Equatable {
    case idle
    case downloading
    case ready
    case failed(String)
}

/// The single shared playback engine. Owns one AVPlayer, drives progress UI via a
/// periodic time observer, persists position to the Book, and mirrors state to the
/// lock screen. UI binds to its @Observable properties.
@MainActor
@Observable
final class PlayerEngine {
    private(set) var currentBook: Book?
    private(set) var isPlaying = false
    var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var loadState: PlayerLoadState = .idle
    @ObservationIgnored private var pendingPlay = false
    @ObservationIgnored private var pendingStart: Double = 0
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private let levelTap = AudioLevelTap()
    @ObservationIgnored private let nowPlaying = NowPlayingCenter()
    @ObservationIgnored private var lastSaved: Double = 0
    @ObservationIgnored let sleepTimer = SleepTimer()
    @ObservationIgnored let stats: ListeningStats
    /// Previous time-observer sample, for crediting only small forward steps. `nil` after a
    /// seek/load/pause so the next tick re-establishes a baseline without counting the gap.
    @ObservationIgnored private var lastTickTime: Double?
    /// True while an `AVPlayer.seek` is still settling. The seek is async: until it lands the
    /// player keeps reporting the *old* position, so a periodic tick would overwrite `currentTime`
    /// back to where we just skipped from — the scrubber's "jumps backward before moving forward"
    /// glitch. While set, the time observer drops its samples so the optimistic target stands.
    @ObservationIgnored private var isSeeking = false
    /// Bumped on every `seek`. A seek's completion only clears `isSeeking` when its token still
    /// matches — so a burst of seeks (a scrubber drag) keeps the guard up until the *last* seek
    /// lands, instead of an early superseded completion clearing it prematurely.
    @ObservationIgnored private var seekToken = 0
    /// Wall-clock time playback was last paused (or, for a launch-restored book,
    /// when it was last played). Drives Smart Rewind on the next `play()`; `nil`
    /// once consumed so a resume is never rewound twice.
    @ObservationIgnored private var lastPausedAt: Date?

    init(stats: ListeningStats) {
        self.stats = stats
        configureAudioSession()
        nowPlaying.configureCommands(
            .init(
                play: { [weak self] in MainActor.assumeIsolated { self?.play() } },
                pause: { [weak self] in MainActor.assumeIsolated { self?.pause() } },
                skipForward: { [weak self] in MainActor.assumeIsolated { self?.skipForward() } },
                skipBackward: { [weak self] in MainActor.assumeIsolated { self?.skipBack() } },
                seek: { [weak self] t in MainActor.assumeIsolated { self?.seek(to: t) } }
            ))
        sleepTimer.onExpire = { [weak self] in self?.pause() }
        registerWidgetToggleObserver()
        registerInterruptionObserver()
    }

    private func configureAudioSession() {
        // Setting the category alone does NOT interrupt other apps' audio — activation does.
        // So configure the category at launch but defer setActive(true) to the first play(),
        // otherwise merely opening the app would pause Spotify/podcasts/etc.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: interruptions

    /// Subscribes to audio-session interruptions (a phone call, a video, another player
    /// grabbing the session). iOS silences our `AVPlayer` on an interruption but issues no
    /// transport callback, so without this `isPlaying` would stay `true` and both the in-app
    /// play/pause button and the Home Screen widget would keep showing "pause" while nothing
    /// actually plays. The engine is app-lifetime-long, so the observer is never removed.
    private func registerInterruptionObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleInterruption(note) }
        }
    }

    /// Parses an interruption notification and reconciles playback per `PlaybackInterruption`.
    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
            let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }
        let shouldResume =
            (info[AVAudioSessionInterruptionOptionKey] as? UInt)
            .map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) }
            ?? false
        switch PlaybackInterruption.response(
            type: type, wasPlaying: isPlaying, shouldResume: shouldResume)
        {
        case .pause: pause()
        case .resume: play()
        case .ignore: break
        }
    }

    var currentChapterIndex: Int {
        guard let book = currentBook else { return 0 }
        return BookMath.locate(progress: currentTime, durations: book.chapterDurations).index
    }

    /// Latest audio loudness (≈0…1) for the level fill inside the play/pause glyph. Returns
    /// 0 when not playing so the level drains to empty. Read once per frame by
    /// `LevelFillEffect`; intentionally NOT an @Observable property — the view's
    /// `TimelineView` already redraws every frame, so observation would be redundant.
    func currentAudioRMS() -> Float {
        isPlaying ? levelTap.currentLevel() : 0
    }

    // MARK: load / transport

    /// Loads a book into the engine. When the file is already on-device it prepares
    /// synchronously (no flicker). When it isn't, `autoDownload` decides what happens:
    /// `true` (the explicit play path) starts the iCloud download immediately; `false`
    /// (launch mini-player restore) leaves the engine idle so we never pull a large
    /// file the user didn't ask to hear — the download then starts on the first `play()`.
    func load(_ book: Book, startAt seconds: Double? = nil, autoDownload: Bool = true) {
        if currentBook?.id == book.id {
            if let s = seconds { seek(to: s) }
            publishWidgetSnapshot()
            return
        }
        loadTask?.cancel()
        loadTask = nil
        pendingPlay = false
        // Switching to a different book: stop and tear down the outgoing item NOW so its
        // audio doesn't keep playing under the new book while the new one prepares — a remote
        // book can take seconds to download, and without this the old audio plays on while the
        // UI already shows the new book. Persist the outgoing position first, but only when an
        // item was actually loaded: a launch-deferred book has currentTime 0 that doesn't
        // reflect its real saved spot (mirrors releaseDownload's hasItem guard).
        if currentBook != nil {
            if timeObserver != nil { saveProgress(force: true) }
            player.pause()
            player.replaceCurrentItem(with: nil)
            levelTap.reset()
            if let obs = timeObserver {
                player.removeTimeObserver(obs)
                timeObserver = nil
            }
            isPlaying = false
        }
        currentBook = book
        lastTickTime = nil
        currentTime = 0
        duration = book.durationSeconds

        let url = M4BImporter.fileURL(for: book.fileName)
        let start = seconds ?? book.progressSeconds
        pendingStart = start

        // Launch-restored books (autoDownload: false) rewind on their first resume,
        // measured from when the user last listened. Explicit play() paths don't —
        // there's no pause to account for, so clear any stale stamp from a prior
        // book's pause (this is a different book — the early return above handled
        // same-book reloads). Applies whether or not the file is local.
        lastPausedAt = autoDownload ? nil : book.lastPlayedAt

        if FileDownloader.isDownloaded(at: url) {
            prepareItem(at: url, startAt: start)
        } else if autoDownload {
            beginDownload(for: book)
        } else {
            loadState = .idle  // wait for an explicit play() before fetching from iCloud
            updateNowPlaying()
        }
        publishWidgetSnapshot()
    }

    /// Materializes the current book's file from iCloud, then prepares it. If it turns
    /// out already local, prepares immediately. Used by both the cold-start play path
    /// and `play()` resuming a launch-restored (deferred) book.
    private func beginDownload(for book: Book) {
        let url = M4BImporter.fileURL(for: book.fileName)
        let start = pendingStart
        if FileDownloader.isDownloaded(at: url) {
            prepareItem(at: url, startAt: start)
            return
        }
        loadState = .downloading
        updateNowPlaying()
        loadTask = Task { [weak self] in
            do {
                try await FileDownloader.ensureDownloaded(at: url)
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.prepareItem(at: url, startAt: start) }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    // Clear the deferred play intent so a later successful download (e.g. a
                    // manual retry) doesn't silently auto-start playback the user didn't ask for.
                    self?.pendingPlay = false
                    self?.loadState = .failed(
                        L.string(
                            "Couldn't download this audiobook. Check your connection and iCloud."))
                }
            }
        }
    }

    /// Builds the player item once the file is local, seeks to the resume point, and
    /// auto-starts playback if `play()` was tapped while the download was in flight.
    private func prepareItem(at url: URL, startAt startSeconds: Double) {
        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .timeDomain
        levelTap.reset()
        player.replaceCurrentItem(with: item)
        // Install the loudness meter that drives the play/pause button's liquid fill.
        // The audio track loads asynchronously; attaching audioMix after playback has
        // started is supported, so the prepare path stays synchronous. No track → the
        // mix is nil and the meter simply reads 0 (calm baseline).
        Task { [levelTap] in
            if let mix = await levelTap.makeAudioMix(for: item) { item.audioMix = mix }
        }
        addTimeObserver()
        var start = startSeconds
        if duration > 0, start >= duration { start = 0 }  // a finished book restarts from the beginning, not the end
        seek(to: start)
        loadState = .ready
        updateNowPlaying()
        if pendingPlay {
            pendingPlay = false
            play()
        }
    }

    /// Rewinds the resume position by a pause-duration-scaled amount when Smart
    /// Rewind is on. Handles every resume path: when the item is ready it seeks;
    /// when the file is still loading or was launch-deferred it shaves `pendingStart`
    /// so `prepareItem` lands at the rewound spot. Consumes `lastPausedAt` so a
    /// resume is never rewound twice. No-op when disabled or never paused.
    private func applySmartRewind() {
        guard let pausedAt = lastPausedAt else { return }
        lastPausedAt = nil
        guard SmartRewindPreference().isEnabled else { return }
        let elapsed = Date().timeIntervalSince(pausedAt)
        let rewind = PlaybackMath.smartRewind(pausedFor: elapsed)
        guard rewind > 0 else { return }
        if loadState == .ready {
            seek(to: currentTime - rewind)  // seek() clamps at 0
        } else {
            pendingStart = max(0, pendingStart - rewind)
        }
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard let book = currentBook else { return }
        applySmartRewind()
        // Tapped play while the file is still downloading: remember the intent and
        // start automatically once `prepareItem` lands.
        if loadState == .downloading {
            pendingPlay = true
            return
        }
        // Tapped play on a launch-restored book whose file isn't local yet: start the
        // download now (deferred from load) and auto-play when it lands.
        if loadState != .ready {
            pendingPlay = true
            beginDownload(for: book)
            return
        }
        activateAudioSession()  // claim the audio session only now — when the user actually starts listening
        player.rate = Float(book.speed)
        isPlaying = true
        book.lastPlayedAt = .now
        updateNowPlaying()
        publishWidgetSnapshot()
    }

    func pause() {
        player.pause()
        isPlaying = false
        lastTickTime = nil
        lastPausedAt = Date()
        saveProgress(force: true)
        updateNowPlaying()
        publishWidgetSnapshot()
    }

    /// Marks a book finished from outside playback (the library menu). Zeroes its saved
    /// position so it leaves "Continue Listening"; if it's the loaded book, ejects it so the
    /// mini player disappears and the next playback tick can't re-save the old position.
    func markFinished(_ book: Book) {
        stats.recordFinish(bookID: book.id.uuidString)
        book.progressSeconds = 0
        // A never-played book has no `lastPlayedAt`; stamp it so the library's finished
        // heuristic (progress == 0 && lastPlayedAt != nil) recognizes it as finished
        // rather than leaving it in "Not Started". Leave an existing timestamp untouched.
        if book.lastPlayedAt == nil { book.lastPlayedAt = .now }
        eject(book)  // no-op unless this is the currently loaded book
    }

    /// Clears a book's saved position so it restarts from the beginning and leaves
    /// "Continue Listening". If it's the loaded book, ejects it (stop + unload) first.
    /// Unlike `markFinished`, this records no finish — listening time is unaffected.
    func resetProgress(_ book: Book) {
        book.progressSeconds = 0
        eject(book)  // no-op unless this is the currently loaded book
    }

    /// Releases this device's local file for `book` without forgetting it — used when the
    /// user removes the download of the book that's currently loaded. Stops playback and
    /// tears down the AVPlayer item (the file is about to be evicted) but KEEPS
    /// `currentBook`, the resume position, and the now-playing entry, so the mini player
    /// stays put. The next `play()` sees `loadState == .idle`, re-downloads, and resumes
    /// from where it left off. No-op unless `book` is the loaded one.
    func releaseDownload(_ book: Book) {
        guard currentBook?.id == book.id else { return }
        // If an item is loaded, `currentTime` is authoritative — persist it and resume there.
        // If the book was only launch-restored (deferred, no item), `currentTime` is 0 and does
        // NOT reflect the real position: keep the saved `progressSeconds` instead of clobbering it.
        let hasItem = timeObserver != nil
        if hasItem {
            saveProgress(force: true)
            pendingStart = currentTime  // resume here once the file re-downloads
        } else {
            pendingStart = book.progressSeconds
        }
        loadTask?.cancel()
        loadTask = nil
        pendingPlay = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        levelTap.reset()
        if let obs = timeObserver {
            player.removeTimeObserver(obs)
            timeObserver = nil
        }
        isPlaying = false
        lastTickTime = nil
        loadState = .idle
        updateNowPlaying()  // keeps the book on screen, now paused
    }

    /// Unloads a book from the engine if it's the loaded one — called before the book is
    /// deleted, so the AVPlayer/time-observer/now-playing state don't outlive the record.
    func eject(_ book: Book) {
        guard currentBook?.id == book.id else { return }
        loadTask?.cancel()
        loadTask = nil
        pendingPlay = false
        loadState = .idle
        player.pause()
        player.replaceCurrentItem(with: nil)
        levelTap.reset()
        if let obs = timeObserver {
            player.removeTimeObserver(obs)
            timeObserver = nil
        }
        isPlaying = false
        lastTickTime = nil
        currentTime = 0
        duration = 0
        lastSaved = 0
        currentBook = nil
        nowPlaying.clear()
        publishWidgetSnapshot()
    }

    func seek(to seconds: Double) {
        let clamped = min(max(0, seconds), max(0, duration))
        currentTime = clamped
        lastTickTime = nil
        // Hold off the periodic observer until the (async) seek lands — otherwise a tick fired
        // mid-seek reports the pre-seek position and snaps `currentTime` backward. The token
        // ensures only the latest seek in a burst (a scrubber drag) clears the guard.
        isSeeking = true
        seekToken += 1
        let token = seekToken
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600)) { _ in
            Task { @MainActor [weak self] in
                guard let self, token == self.seekToken else { return }
                self.isSeeking = false
            }
        }
        saveProgress(force: true)
        updateNowPlaying()
    }

    func skipBack() { seek(to: PlaybackMath.skipBack(from: currentTime, total: duration)) }
    func skipForward() { seek(to: PlaybackMath.skipForward(from: currentTime, total: duration)) }

    func seekToChapter(_ index: Int) {
        guard let book = currentBook else { return }
        seek(to: BookMath.chapterBase(index: index, durations: book.chapterDurations))
    }

    /// Jumps to the start of the next chapter. No-op on the last chapter.
    func nextChapter() {
        guard let book = currentBook else { return }
        let next = currentChapterIndex + 1
        guard next < book.chapterDurations.count else { return }
        seekToChapter(next)
    }

    /// Jumps to the previous chapter — but if we're more than 3s into the current chapter,
    /// restarts it instead, matching the familiar track-back behavior on the first chapter too.
    func previousChapter() {
        guard let book = currentBook else { return }
        let index = currentChapterIndex
        let base = BookMath.chapterBase(index: index, durations: book.chapterDurations)
        if currentTime - base > 3 {
            seek(to: base)
        } else {
            seekToChapter(max(0, index - 1))
        }
    }

    func setSpeed(_ speed: Double) {
        guard let book = currentBook else { return }
        book.speed = speed
        if isPlaying { player.rate = Float(book.speed) }
        updateNowPlaying()
    }

    // MARK: progress observer + persistence

    private func addTimeObserver() {
        if let obs = timeObserver {
            player.removeTimeObserver(obs)
            timeObserver = nil
        }
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                let t = time.seconds
                guard t.isFinite else { return }  // CMTime is NaN/indefinite mid-seek or before the item is ready
                guard !self.isSeeking else { return }  // drop pre-seek samples until the seek lands (no backward snap)
                if self.isPlaying, let last = self.lastTickTime {
                    self.stats.addListened(PlaybackMath.listenedDelta(from: last, to: t))
                }
                self.lastTickTime = t
                self.currentTime = t
                if self.currentTime >= self.duration, self.duration > 0 {
                    self.currentTime = self.duration
                    if self.isPlaying { self.finishPlayback() }  // act only on the end transition; later ticks are no-ops
                    return  // don't fall through and persist `duration` as the resume position
                }
                self.saveProgress(force: false)
            }
        }
    }

    /// Called once when playback reaches the end. Stops and resets the saved position to 0 so the
    /// book leaves "Continue" and replays from the start next time — instead of persisting `duration`,
    /// which would strand it at the end showing "0m left" and auto-pausing on every resume.
    private func finishPlayback() {
        player.pause()
        isPlaying = false
        if let id = currentBook?.id { stats.recordFinish(bookID: id.uuidString) }
        currentBook?.progressSeconds = 0
        lastSaved = 0
        updateNowPlaying()
        publishWidgetSnapshot()
    }

    private func saveProgress(force: Bool) {
        guard let book = currentBook else { return }
        if force || abs(currentTime - lastSaved) >= 5 {
            book.progressSeconds = currentTime
            lastSaved = currentTime
        }
    }

    private func updateNowPlaying() {
        guard let book = currentBook else {
            nowPlaying.clear()
            return
        }
        nowPlaying.update(
            title: book.title, author: book.author, artwork: book.artworkData,
            duration: duration, elapsed: currentTime,
            rate: isPlaying ? book.speed : 0
        )
    }

    // MARK: widget snapshot

    @ObservationIgnored private let widgetStore = WidgetSnapshotStore()

    /// Mirrors the current book + play state to the App Group so the Recent widget can
    /// render and toggle it, then asks WidgetKit to refresh. Called at every transition
    /// that changes `currentBook` or `isPlaying`.
    private func publishWidgetSnapshot() {
        guard let book = currentBook else {
            widgetStore.write(.empty)
            widgetStore.writeArtwork(nil)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.recentKind)
            return
        }
        let hasArt = (book.artworkData?.isEmpty == false)
        widgetStore.write(
            RecentSnapshot(
                bookID: book.id.uuidString, title: book.title, author: book.author,
                tint: book.tint, isPlaying: isPlaying, hasArtwork: hasArt))
        widgetStore.writeArtwork(Self.thumbnail(from: book.artworkData))
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.recentKind)
    }

    /// Downscales cover artwork to a small JPEG for the widget (covers are large; the
    /// widget only renders a ~64pt square). Returns nil when there's no artwork.
    private static func thumbnail(from data: Data?, maxDimension: CGFloat = 240) -> Data? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: widget toggle

    /// Listens for the Darwin notification posted by the widget's `TogglePlaybackIntent`.
    /// Because that intent is an `AudioStartingIntent`, the system runs it in this process —
    /// background-launching the app when needed — so the observer is alive to receive the
    /// post even from a cold tap. The observer carries no payload, so we capture `self` via
    /// the engine instance pointer.
    private func registerWidgetToggleObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = WidgetConstants.toggleDarwinName as CFString
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center, observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let engine = Unmanaged<PlayerEngine>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in engine.handleWidgetToggle() }
            },
            name, nil, .deliverImmediately)
    }

    /// Handles a widget play/pause. With a book loaded, toggles it. With nothing loaded —
    /// the app was background-launched cold by the widget's `AudioStartingIntent`, so the
    /// launch mini-player restore (a scene-only path) never ran — it resolves the most
    /// recent book from the shared snapshot and starts it from its saved position.
    func handleWidgetToggle() {
        if currentBook != nil {
            toggle()
            return
        }
        let snap = widgetStore.read()
        guard !snap.isEmpty, let id = UUID(uuidString: snap.bookID),
            let book = AppModelContainer.fetchBook(id: id)
        else { return }
        load(book)  // autoDownload: true — pulls the file if it isn't local yet
        play()  // plays now, or auto-plays once the download lands (pendingPlay)
    }
}
