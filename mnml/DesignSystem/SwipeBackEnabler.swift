//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftUI
import UIKit

/// Re-enables the interactive edge-swipe-to-go-back gesture for the screen it's attached to.
///
/// `NavigationStack` is backed by a `UINavigationController` whose swipe-to-pop gesture is only
/// permitted while the *standard* back button is showing. A screen that hides it — via
/// `navigationBarBackButtonHidden(true)` to use a custom back control — therefore loses the
/// swipe. This walks up to the hosting nav controller and substitutes the gesture's delegate so
/// the swipe fires whenever the stack has something to pop to.
///
/// It's scoped: the original delegate is captured on appear and restored on disappear, so the
/// nav controller is left untouched once this screen is gone (and we never leave the recognizer
/// with a nil delegate, which would break the transition). Only the `.delegate` is swapped —
/// the recognizer's target/action that actually drives the pop stays intact, so the interactive
/// transition still works.
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        Proxy(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?
        weak var originalDelegate: UIGestureRecognizerDelegate?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }

    /// An invisible child view controller used purely to reach the hosting `UINavigationController`.
    final class Proxy: UIViewController {
        let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
            view.isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let gesture = navigationController?.interactivePopGestureRecognizer,
                gesture.delegate !== coordinator
            else { return }
            coordinator.navigationController = navigationController
            coordinator.originalDelegate = gesture.delegate
            gesture.delegate = coordinator
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // Restore the original delegate so the nav controller is unchanged once we leave,
            // and so the recognizer is never left with a (weak, soon-nil) delegate.
            if let gesture = coordinator.navigationController?.interactivePopGestureRecognizer,
                gesture.delegate === coordinator
            {
                gesture.delegate = coordinator.originalDelegate
            }
        }
    }
}

extension View {
    /// Re-enables swipe-to-go-back on a screen that hides the system back button.
    func enablesSwipeBack() -> some View {
        background(SwipeBackEnabler().frame(width: 0, height: 0))
    }
}
