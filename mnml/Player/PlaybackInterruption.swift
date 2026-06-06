//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import AVFoundation

/// Pure policy for how the engine should react to an `AVAudioSession` interruption — another
/// app taking the audio session (a phone call, a video, a music app). Extracted as a
/// `nonisolated`, side-effect-free function so the decision is unit-testable without a live
/// audio session; `PlayerEngine` parses the notification and applies the result.
enum PlaybackInterruption {
    enum Response: Equatable {
        case pause  // sync our state to "not playing" — the system already silenced us
        case resume  // restart playback
        case ignore
    }

    /// - `.began` while we were playing → `.pause`. iOS has already stopped our `AVPlayer`
    ///   but sends no transport callback, so we must reconcile `isPlaying` ourselves.
    /// - `.ended` with `.shouldResume` → `.resume`. The system marks transient interruptions
    ///   (e.g. a finished call) resumable; a non-transient one (another app keeps playing)
    ///   omits the flag, so we stay paused rather than yanking audio back from the user.
    nonisolated static func response(
        type: AVAudioSession.InterruptionType,
        wasPlaying: Bool,
        shouldResume: Bool
    ) -> Response {
        switch type {
        case .began: return wasPlaying ? .pause : .ignore
        case .ended: return shouldResume ? .resume : .ignore
        @unknown default: return .ignore
        }
    }
}
