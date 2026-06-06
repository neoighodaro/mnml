//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import CloudKit
import Foundation

/// Reactive iCloud account availability, for UI honesty. Distinct from the
/// synchronous launch gate `ICloudAccount` (token-only): this refines raw
/// `ubiquityIdentityToken` presence with `CKContainer.accountStatus`, so the UI can
/// tell "signed in and syncing" from "signed in but CloudKit is restricted /
/// temporarily unavailable" — the states behind the runtime's iCloud-account log
/// noise.
///
/// Lives in the SwiftUI environment beside `CloudSyncMonitor`. Recomputes on iCloud
/// identity and CloudKit account-change notifications, so Settings and the library
/// reflect a sign-in/out without an app restart.
@MainActor
@Observable
final class ICloudAccountMonitor {
    enum Availability: Equatable {
        case available  // signed in and CloudKit reachable
        case noAccount  // not signed into iCloud
        case restricted  // account restricted (parental controls / MDM)
        case unavailable  // transient/unknown: temporarilyUnavailable or couldNotDetermine
    }

    private(set) var availability: Availability = .unavailable

    /// True only when sync can actually happen right now.
    var isSyncable: Bool { availability == .available }

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init() {
        let center = NotificationCenter.default
        for name: NSNotification.Name in [.NSUbiquityIdentityDidChange, .CKAccountChanged] {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleRefresh() }
                })
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Pure mapping from the two underlying signals to a single availability. Static
    /// and side-effect free so it is unit-testable without an iCloud account.
    /// `nonisolated` because it touches no actor state — lets synchronous tests call
    /// it directly without hopping to the main actor.
    nonisolated static func derive(hasToken: Bool, ckStatus: CKAccountStatus) -> Availability {
        guard hasToken else { return .noAccount }
        switch ckStatus {
        case .available: return .available
        case .restricted: return .restricted
        case .noAccount: return .noAccount
        case .temporarilyUnavailable: return .unavailable
        case .couldNotDetermine: return .unavailable
        @unknown default: return .unavailable
        }
    }

    /// Re-reads both signals and updates `availability`. Token is synchronous;
    /// `accountStatus` is async. Idempotent — safe to call repeatedly.
    func refresh() async {
        let hasToken = FileManager.default.ubiquityIdentityToken != nil
        let status: CKAccountStatus
        do {
            status = try await CKContainer(identifier: UbiquityContainer.identifier).accountStatus()
        } catch {
            status = .couldNotDetermine
        }
        guard !Task.isCancelled else { return }  // a newer refresh superseded this one
        availability = Self.derive(hasToken: hasToken, ckStatus: status)
    }

    private func scheduleRefresh() {
        // Supersede any in-flight refresh so overlapping account-change notifications
        // can't land out of order and leave a stale `availability`.
        refreshTask?.cancel()
        refreshTask = Task { await refresh() }
    }
}
