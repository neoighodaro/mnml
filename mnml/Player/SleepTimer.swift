//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import Foundation

/// Sleep timer: the user picks a duration (0 = off); owns a countdown Task that fires
/// `onExpire` (used to pause playback) when it elapses. The available durations live in the
/// picker in `NowPlayingView`.
@Observable
@MainActor
final class SleepTimer {
    private(set) var minutes: Int = 0
    private var task: Task<Void, Never>?
    var onExpire: (() -> Void)?

    nonisolated static func label(for minutes: Int) -> String? {
        minutes > 0 ? "\(minutes)m" : nil
    }

    var label: String? { Self.label(for: minutes) }

    /// Jump directly to a specific option (used by the picker). `arm()` cancels the running
    /// task and either rearms with the new duration or stays off when 0.
    func set(minutes: Int) {
        self.minutes = minutes
        arm()
    }

    func cancel() {
        minutes = 0
        task?.cancel()
        task = nil
    }

    private func arm() {
        task?.cancel()
        guard minutes > 0 else {
            task = nil
            return
        }
        let seconds = UInt64(minutes) * 60
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double(seconds)))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.onExpire?()
                self?.minutes = 0
            }
        }
    }
}
