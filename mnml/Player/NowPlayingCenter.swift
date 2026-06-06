//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import MediaPlayer
import UIKit

/// Bridges player state to the lock screen / Control Center. The engine owns one
/// instance and calls `update` on every state change; `configureCommands` wires
/// the remote buttons back to the engine's closures.
///
/// `@MainActor` because `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` require
/// main-thread access; the owning engine is also `@MainActor`.
///
/// The closures in `Handlers` are retained for the process lifetime (the remote
/// command center is a singleton), so callers must capture `self` weakly inside them.
@MainActor
final class NowPlayingCenter {
    struct Handlers {
        let play: () -> Void
        let pause: () -> Void
        let skipForward: () -> Void
        let skipBackward: () -> Void
        let seek: (Double) -> Void
    }

    private var isConfigured = false

    func configureCommands(_ h: Handlers) {
        guard !isConfigured else { return }  // remote commands are a process-wide singleton; register once
        isConfigured = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { _ in
            h.play()
            return .success
        }
        c.pauseCommand.addTarget { _ in
            h.pause()
            return .success
        }

        c.skipForwardCommand.preferredIntervals = [30]
        c.skipForwardCommand.addTarget { _ in
            h.skipForward()
            return .success
        }
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.addTarget { _ in
            h.skipBackward()
            return .success
        }

        c.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            h.seek(e.positionTime)
            return .success
        }
    }

    func update(
        title: String, author: String, artwork: Data?,
        duration: Double, elapsed: Double, rate: Double
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: author,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
        ]
        if let data = artwork, let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
