//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import AVKit
import SwiftUI

/// The AirPlay route picker, wrapped for SwiftUI. AirPlay output already works via the
/// shared audio session; this just surfaces Apple's route picker inside the player so the
/// user doesn't have to leave for Control Center. The glyph turns `accent` when a non-local
/// route (AirPlay speaker, Apple TV, Bluetooth) is active, giving free "casting" feedback.
struct AirPlayButton: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.delegate = context.coordinator
        view.prioritizesVideoDevices = false  // audio app — never bias toward video routes
        view.tintColor = UIColor(Theme.text2)
        view.activeTintColor = UIColor(Theme.accent)
        view.backgroundColor = .clear
        // Don't let the picker stretch; keep it glyph-sized so it sits level with the
        // sibling icons in the player's secondary row.
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {}

    /// The picker presents its own route sheet on tap; we only hook the delegate to fire a
    /// haptic as it opens — keeping the haptic out of the SwiftUI builder closure.
    final class Coordinator: NSObject, AVRoutePickerViewDelegate {
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            Haptics.tap()
        }
    }
}
