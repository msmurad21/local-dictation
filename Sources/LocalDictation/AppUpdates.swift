import AppKit
import Combine
import Network
import Sparkle
import SwiftUI
import DictationCore

@MainActor final class AppUpdates: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var configured = false
    @Published private(set) var canCheck = false
    @Published private(set) var status = "Updates will be available once the release channel is configured."
    @Published private(set) var automatic = false
    private(set) var isInstalling = false
    private var controller: SPUStandardUpdaterController?
    private var observations = Set<AnyCancellable>()
    private var monitor: NWPathMonitor?
    private var timer: Timer?
    private var install: (() -> Void)?
    private var automaticInstall = false
    private var idleSince: Date?
    private var lastNetworkCheck = Date.distantPast
    var safeToRestart: () -> Bool = { false }
    var prepareToRestart: () -> Void = {}

    func start() {
        guard controller == nil,
              UpdatePolicy.validConfiguration(feed: Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
                                              publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String) else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        do { try controller.updater.start() }
        catch { status = "Updates unavailable: \(error.localizedDescription)"; return }
        configured = true; status = "Automatic updates are ready."
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .combineLatest(controller.updater.publisher(for: \.automaticallyDownloadsUpdates))
            .sink { [weak self] checks, downloads in self?.automatic = checks && downloads }
            .store(in: &observations)
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in self?.checkAfterReconnection() }
        }
        monitor.start(queue: DispatchQueue(label: "local.dictation.updates.network")); self.monitor = monitor
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.installWhenIdle() }
        }
    }
    func setAutomatic(_ enabled: Bool) {
        controller?.updater.automaticallyDownloadsUpdates = enabled
        controller?.updater.automaticallyChecksForUpdates = enabled
        status = enabled ? "Updates download automatically and install when dictation is idle." : "Automatic updates are off. You can still check manually."
    }
    @objc func checkForUpdates() {
        guard canCheck else { return }
        controller?.checkForUpdates(nil)
    }
    private func checkAfterReconnection() {
        guard let updater = controller?.updater, updater.automaticallyChecksForUpdates,
              updater.canCheckForUpdates, Date().timeIntervalSince(lastNetworkCheck) >= 3600 else { return }
        lastNetworkCheck = Date()
        updater.checkForUpdatesInBackground()
    }
    private func installWhenIdle() {
        guard let install, (!automaticInstall || automatic), safeToRestart() else { idleSince = nil; return }
        guard let idleSince else { self.idleSince = Date(); return }
        guard Date().timeIntervalSince(idleSince) >= 60 else { return }
        self.install = nil; self.idleSince = nil
        isInstalling = true
        prepareToRestart()
        UserDefaults.standard.set(true, forKey: "resumeAfterUpdate")
        install()
    }
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        install = immediateInstallHandler; automaticInstall = true; idleSince = nil
        status = "Update downloaded. Waiting for a quiet moment to restart."
        return true
    }
    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard !safeToRestart() else { isInstalling = true; prepareToRestart(); return false }
        install = installHandler; automaticInstall = false; idleSince = nil
        status = "Update ready. Finish dictation and copy any unpasted text first."
        return true
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error { isInstalling = false; status = "Update check: \(error.localizedDescription)" }
        else if install == nil { status = "Update check completed." }
    }
    func shutdown() { timer?.invalidate(); monitor?.cancel() }
}

struct UpdateSettingsView: View {
    @ObservedObject var updates: AppUpdates
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App updates").font(.headline)
            Toggle("Automatically download and install updates", isOn: Binding(get: { updates.automatic }, set: updates.setAutomatic))
                .disabled(!updates.configured)
            Text(updates.status).font(.caption).foregroundStyle(.secondary)
            Text("Checks hourly when online. Installation waits until dictation is idle and unpasted text is copied. Speech stays on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Check for Updates…") { updates.checkForUpdates() }.disabled(!updates.canCheck)
        }
    }
}
