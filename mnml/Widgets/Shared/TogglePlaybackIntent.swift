//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//
import AppIntents
import Foundation

/// Toggles playback of the recent book from the widget.
///
/// Conforms to `AudioPlaybackIntent`: the system runs the intent **inside the app's
/// process**, background-launching the app if it isn't running (requires the app's
/// "audio" background mode). That's what lets play/pause work when the app is closed —
/// a plain `AppIntent` runs in the widget's process, where it can't touch the player.
///
/// We still drive playback indirectly via a Darwin notification rather than calling the
/// engine here, so this file stays free of app-only symbols and compiles into the widget
/// extension too (the widget needs the type to build its `Button(intent:)`). By the time
/// `perform()` runs, the app process is alive, so `PlayerEngine`'s observer is listening
/// and `handleWidgetToggle()` either toggles the loaded book or cold-starts the recent one.
struct TogglePlaybackIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var isDiscoverable = false  // widget-only, not in Shortcuts

    func perform() async throws -> some IntentResult {
        let store = WidgetSnapshotStore()
        let snap = store.read()
        guard !snap.isEmpty else { return .result() }
        store.setPlaying(!snap.isPlaying)  // optimistic flip for instant widget feedback

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center, CFNotificationName(WidgetConstants.toggleDarwinName as CFString),
            nil, nil, true)
        return .result()
    }
}
