//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(PlayerEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Environment(ICloudAccountMonitor.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(L.languageKey) private var languageRaw = AppLanguage.en.rawValue
    @AppStorage(CloudSyncPreference.storageKey) private var iCloudSyncEnabled = false
    @AppStorage(SmartRewindPreference.storageKey) private var smartRewindEnabled = true
    @Query private var books: [Book]
    @State private var store: LibraryStore?
    @State private var confirmingDisable = false
    @State private var confirmingClear = false
    @State private var freeingUpSpace = false
    @State private var storage = StorageUsage.Totals()

    private var appearance: Appearance { Appearance(rawValue: appearanceRaw) ?? .system }
    private var language: AppLanguage { AppLanguage(rawValue: languageRaw) ?? .en }

    /// The on-device storage label, named for the hardware so it reads concretely
    /// against "Entire Library" ("On This iPhone" vs "On This iPad"). Three distinct
    /// keys rather than a "On This %@" format, so each translates with its own
    /// article/word order.
    private var deviceLabel: LocalizedStringKey {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: return "On This iPad"
        case .mac: return "On This Mac"
        default: return "On This iPhone"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Appearance").eyebrowStyle().padding(.bottom, 8)
                segmentedRow(
                    Appearance.allCases.map { (Text($0.titleKey), $0) },
                    selection: appearance,
                    select: { appearanceRaw = $0.rawValue }
                )

                Text("Language").eyebrowStyle().padding(.top, 30).padding(.bottom, 8)
                segmentedRow(
                    AppLanguage.allCases.map { (Text(verbatim: $0.displayName), $0) },
                    selection: language,
                    select: { languageRaw = $0.rawValue }
                )

                Text("Smart Rewind").eyebrowStyle().padding(.top, 30).padding(.bottom, 8)
                segmentedRow(
                    [(Text("Off"), false), (Text("On"), true)],
                    selection: smartRewindEnabled,
                    select: { smartRewindEnabled = $0 }
                )

                Text("Storage").eyebrowStyle().padding(.top, 30).padding(.bottom, 4)
                optionsCard {
                    // Sync leads the card: it's the switch that decides whether storage
                    // spans devices, so the figures below read as its consequence.
                    syncRow
                    rowDivider
                    if iCloudSyncEnabled {
                        // With sync on, the library spans devices, so distinguish the full
                        // collection from what's actually taking up room on this one.
                        storageRow(
                            "Entire Library",
                            detail: "Every audiobook, including titles kept in iCloud",
                            bytes: storage.libraryBytes)
                        rowDivider
                        storageRow(
                            deviceLabel,
                            detail: "Stored on this device for offline listening",
                            bytes: storage.downloadedBytes)
                        // Only when there's something to reclaim — eviction needs an iCloud
                        // copy to fall back on, which only exists while sync is on.
                        if storage.downloadedBytes > 0 {
                            rowDivider
                            freeUpSpaceRow
                        }
                    } else {
                        // Local-only: there's no cloud copy, so one figure says it all, and
                        // "Free Up Space" can't apply — evicting would destroy the only copy.
                        storageRow(
                            "Your Library",
                            detail: "Audiobook files stored on this device",
                            bytes: storage.downloadedBytes)
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 6)
            .padding(.bottom, Theme.botSafe + Theme.miniPlayerInset)
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        // Recompute on every appearance so a fresh download/delete is reflected.
        .task {
            if store == nil { store = LibraryStore(context: context) }
            storage = await StorageUsage.measure()
            await account.refresh()
        }
        // Re-check when returning to the app, so a sign-in/out done in system Settings
        // is reflected here.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await account.refresh() } }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        // SwiftUI can't restyle a nav-title font, so override it on this stack's own
        // nav bar (Space Grotesk, matching the old inline header) without touching the
        // system's Liquid Glass background or any other tab's bar.
        .background(NavTitleFont())
        .confirmationDialog(
            "Turn off iCloud Sync?", isPresented: $confirmingDisable, titleVisibility: .visible
        ) {
            Button("Turn Off", role: .destructive) { iCloudSyncEnabled = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Your library and progress will stop syncing on this device. Your audiobook files stay in iCloud Drive — to remove them, delete them in the Files app, or use Delete from Library while sync is on."
            )
        }
        .confirmationDialog(
            "Free up space?", isPresented: $confirmingClear, titleVisibility: .visible
        ) {
            Button("Remove Downloads", role: .destructive) { freeUpSpace() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Removes every audiobook downloaded on this device to free up space. Your books stay in iCloud and re-download when you play them."
            )
        }
    }

    /// The sync toggle, first row of the Storage card. Display is derived from the
    /// stored preference AND the live account state, so a signed-out device shows an
    /// honest "Paused" instead of an ON-but-greyed toggle that implies sync is running.
    private var syncRow: some View {
        let rowState = SyncRowState.resolve(
            prefEnabled: iCloudSyncEnabled,
            availability: account.availability)
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sync Library & Progress")
                    .font(Typography.body(15)).foregroundStyle(Theme.text)
                Text(syncSubtitle(for: rowState))
                    .font(Typography.body(12))
                    .foregroundStyle(Theme.text.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                if rowState == .paused {
                    Text("Paused — signed out")
                        .font(Typography.body(11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // `isOn` reflects whether sync is actually ACTIVE — not the stored intent —
            // so Paused never shows a lit toggle. Intent is preserved in `iCloudSyncEnabled`.
            Toggle(
                isOn: Binding(
                    get: { rowState == .active },
                    set: { newValue in
                        Haptics.tap()
                        if newValue { iCloudSyncEnabled = true } else { confirmingDisable = true }
                    })
            ) {
                // Hidden by .labelsHidden(); verbatim so the empty string isn't
                // extracted into the string catalog as a stray "" key.
                Text(verbatim: "")
            }
            .labelsHidden()
            .tint(Theme.accent)
            .disabled(rowState == .paused || rowState == .signInPrompt)
        }
        .padding(.vertical, 15)
    }

    /// Subtitle copy for each row state.
    private func syncSubtitle(for state: SyncRowState) -> LocalizedStringKey {
        switch state {
        case .active, .off:
            return
                "Keeps your library and listening position in sync across your devices. Changes take effect after restarting the app."
        case .paused:
            return "Sync resumes when you sign back in to iCloud."
        case .signInPrompt:
            return "Sign in to iCloud in Settings to turn on sync."
        }
    }

    /// A tappable row that evicts every local download (keeping iCloud copies), shown
    /// only with sync on and something downloaded. Confirms before acting. While the
    /// eviction is running, a spinner sits left of the label and the row is disabled,
    /// so a slow reclaim doesn't read as an unresponsive tap.
    private var freeUpSpaceRow: some View {
        Button(role: .destructive) {
            Haptics.tap()
            confirmingClear = true
        } label: {
            HStack(spacing: 8) {
                Spacer()
                if freeingUpSpace {
                    ProgressView().controlSize(.small).tint(Theme.accent)
                }
                Text("Free Up Space").font(Typography.body(15))
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(freeingUpSpace)
    }

    /// Evicts all downloads, then re-measures so the figures drop right away. The
    /// `freeingUpSpace` flag drives the row's spinner/disabled state from tap until
    /// the disk has actually been reclaimed and re-measured.
    private func freeUpSpace() {
        Task {
            freeingUpSpace = true
            await store?.removeAllDownloads(books)
            storage = await StorageUsage.measure()
            freeingUpSpace = false
        }
    }

    private func optionsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
    }

    private var rowDivider: some View {
        Rectangle().fill(Theme.hairline(scheme)).frame(height: 0.5)
    }

    /// A storage line: title + one-line explanation on the left, the measured size on
    /// the right. Sizes use the system file-size style ("1.2 GB") and align on digits.
    private func storageRow(_ title: LocalizedStringKey, detail: LocalizedStringKey, bytes: Int64)
        -> some View
    {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Typography.body(15)).foregroundStyle(Theme.text)
                Text(detail)
                    .font(Typography.body(12))
                    .foregroundStyle(Theme.text.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                .font(Typography.body(15, weight: .medium)).monospacedDigit()
                .foregroundStyle(Theme.text2)
        }
        .padding(.vertical, 15)
    }

    /// A compact horizontal segmented control: one selectable pill per option,
    /// themed to match the design system. Replaces the tall checkmark-row cards
    /// for single-choice settings. `options` pairs a display label with its value;
    /// the row tinted with `Theme.accent` is the current `selection`.
    private func segmentedRow<Value: Equatable>(
        _ options: [(label: Text, value: Value)],
        selection: Value,
        select: @escaping (Value) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = option.value == selection
                Button {
                    Haptics.tap()
                    select(option.value)
                } label: {
                    option.label
                        .font(Typography.body(14, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? Color.white : Theme.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.track(scheme))
        }
    }
}

/// Restyles the enclosing navigation bar's large + inline title to Space Grotesk.
/// It reaches the bar through its own hosting controller, so it only affects the
/// nav stack it's embedded in (Settings) and leaves the Liquid Glass background,
/// and every other tab's bar, untouched.
struct NavTitleFont: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Proxy() }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}

    final class Proxy: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let bar = navigationController?.navigationBar else { return }

            func font(_ size: CGFloat) -> UIFont {
                let descriptor = UIFontDescriptor(fontAttributes: [
                    .family: "Space Grotesk",
                    .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.medium],
                ])
                return UIFont(descriptor: descriptor, size: size)
            }
            let color = UIColor(Theme.text)
            let large: [NSAttributedString.Key: Any] =
                [.font: font(32), .foregroundColor: color, .kern: -0.95]
            let inline: [NSAttributedString.Key: Any] =
                [.font: font(17), .foregroundColor: color]

            func styled(_ base: UINavigationBarAppearance?) -> UINavigationBarAppearance {
                let a = (base?.copy() as? UINavigationBarAppearance) ?? UINavigationBarAppearance()
                a.largeTitleTextAttributes = large
                a.titleTextAttributes = inline
                return a
            }
            bar.standardAppearance = styled(bar.standardAppearance)
            bar.scrollEdgeAppearance = styled(bar.scrollEdgeAppearance ?? bar.standardAppearance)
            bar.compactAppearance = styled(bar.compactAppearance ?? bar.standardAppearance)
        }
    }
}
