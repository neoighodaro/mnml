//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import AVFoundation
import Testing

@testable import mnml

struct PlaybackInterruptionTests {
    // Another app grabs the session mid-listen: iOS has already silenced us, so we sync to
    // paused (the fix for the stuck "pause" button + frozen widget).
    @Test func beganWhilePlayingPauses() {
        #expect(
            PlaybackInterruption.response(type: .began, wasPlaying: true, shouldResume: false)
                == .pause)
    }

    // An interruption that begins while we're already paused changes nothing.
    @Test func beganWhilePausedIsIgnored() {
        #expect(
            PlaybackInterruption.response(type: .began, wasPlaying: false, shouldResume: false)
                == .ignore)
    }

    // A transient interruption (e.g. a finished phone call) ends with .shouldResume → resume.
    @Test func endedWithShouldResumeResumes() {
        #expect(
            PlaybackInterruption.response(type: .ended, wasPlaying: false, shouldResume: true)
                == .resume)
    }

    // A non-transient interruption (another app keeps playing) ends without .shouldResume:
    // we stay paused rather than yanking audio back from the user.
    @Test func endedWithoutShouldResumeStaysPaused() {
        #expect(
            PlaybackInterruption.response(type: .ended, wasPlaying: false, shouldResume: false)
                == .ignore)
        #expect(
            PlaybackInterruption.response(type: .ended, wasPlaying: true, shouldResume: false)
                == .ignore)
    }
}
