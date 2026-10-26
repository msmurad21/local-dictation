import AppKit
import AVFoundation
import DictationCore

@MainActor final class DictationController: ObservableObject {
    @Published var status = "Loading local model…"
    @Published var transcript = "" { didSet { hasUnpastedText = !transcript.isEmpty } }
    private(set) var hasUnpastedText = false
    let updates = AppUpdates()
    @Published var error: String?
    @Published var ready = false
    @Published var busy = false
    @Published var recording = false
    @Published var starting = false
    @Published var latched = false
    @Published var submitting = false
    @Published var levels = Array(repeating: Float(0.03), count: 28)
    @Published var elapsed: Double = 0
    @Published var accessibilityReady = AXIsProcessTrusted()
    @Published var fnReady = false
    @Published var autoInsert = UserDefaults.standard.object(forKey: "autoInsert") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoInsert, forKey: "autoInsert") }
    }
    @Published var mode = RecordingMode(rawValue: UserDefaults.standard.string(forKey: "recordingMode") ?? "") ?? .pushToTalk {
        didSet { hotKey.mode = mode; UserDefaults.standard.set(mode.rawValue, forKey: "recordingMode") }
    }
    @Published var showOverlay = UserDefaults.standard.object(forKey: "showOverlay") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showOverlay, forKey: "showOverlay") }
    }
    @Published var soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    private let sounds = RecordingSounds()
    let store = LocalStore()
    private let engine = SpeechEngine()
    private let hotKey = HotKey()
    private var gate = HoldGate()
    private var recorder: AVAudioRecorder?
    private var audioURL: URL?
    private var target: InsertionTarget?
    private var meter: Timer?
    private var permissionTimer: Timer?
    private var generation = 0
    private var workspaceObserver: NSObjectProtocol?
    private(set) var lastExternalApp: NSRunningApplication?
    var showDashboard: (() -> Void)?

    init() {
        lastExternalApp = NSWorkspace.shared.frontmostApplication
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in self?.lastExternalApp = app }
        }
        hotKey.mode = mode
        hotKey.isHandsFree = { [weak self] in
            guard let self else { return false }
            return self.latched && (self.recording || self.starting)
        }
        hotKey.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .beginHold: self.start(latch: false)
            case .endHold: if !self.latched { Task { await self.stop() } }
            case .toggle: self.toggleRecording()
            case .finish: self.finish()
            }
        }
        hotKey.onCancel = { [weak self] in self?.cancel() }
        do { try hotKey.register() } catch { self.error = error.localizedDescription }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.accessibilityReady = AXIsProcessTrusted()
                self.hotKey.refreshFn(); self.fnReady = self.hotKey.fnAvailable
            }
        }
        Task {
            busy = true
            do { try await engine.load(); ready = true; status = "Ready to dictate" }
            catch { status = "Model not ready"; self.error = error.localizedDescription }
            busy = false
        }
    }
    func prepareModel() async {
        guard !busy && !recording else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await engine.prepare { [weak self] message in Task { @MainActor in self?.status = message } }
            ready = true; status = "Ready to dictate"
        } catch { self.error = error.localizedDescription; status = "Model setup failed" }
    }
    func toggleRecording() {
        if recording || starting {
            if !latched { latched = true; status = "Hands-free recording" }
            else { Task { await stop() } }
        } else { start(latch: true) }
    }
    func finish() {
        gate.release()
        if starting { starting = false; latched = false }
        Task { await stop() }
    }
    func start(latch: Bool) {
        guard ready && !busy && !recording && !starting && !updates.isInstalling else { return }
        starting = true; latched = latch
        let token = gate.press()
        error = nil; generation += 1
        Task { [self] in
        // A dashboard click may have activated this app. Return focus before capture.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
           let previous = lastExternalApp, !previous.isTerminated,
           previous.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            hideDashboard()
            previous.activate(options: [])
            try? await Task.sleep(for: .milliseconds(180))
        }
        guard gate.mayStart(token) else { if gate.generation == token { starting = false }; return }
        let selectedTarget = InsertionTarget.capture()
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard gate.mayStart(token) else { if gate.generation == token { starting = false }; return }
        guard allowed else {
            gate.release(); starting = false
            error = "Allow Microphone access in System Settings → Privacy & Security."
            return
        }
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("local-dictation-\(UUID().uuidString).wav")
            audioURL = url
            let capture = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: Int(kAudioFormatLinearPCM), AVSampleRateKey: 16000.0, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
            capture.isMeteringEnabled = true
            guard capture.record() else { throw AppError.message("The microphone could not start recording.") }
            recorder = capture; target = selectedTarget; recording = true; starting = false; elapsed = 0
            levels = Array(repeating: 0.03, count: 28)
            hotKey.canCancel = true
            if soundEnabled { sounds.play(.start) }
            status = latched ? "Hands-free recording" : "Listening · release Fn to finish"
            meter = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let recorder = self.recorder else { return }
                    recorder.updateMeters()
                    let value = max(0.03, min(1, pow(10, recorder.averagePower(forChannel: 0) / 35)))
                    self.levels.removeFirst(); self.levels.append(value)
                    self.elapsed = recorder.currentTime
                    if self.elapsed >= 600 { await self.stop() }
                }
            }
        } catch { gate.release(); starting = false; cleanupAudio(); self.error = error.localizedDescription }
        }
    }
    func stop() async {
        gate.release()
        guard recording, let recorder, let url = audioURL else { return }
        let duration = recorder.currentTime
        recorder.stop(); self.recorder = nil; meter?.invalidate(); meter = nil
        recording = false; latched = false
        if soundEnabled { sounds.play(.stop) }
        guard duration > 0.25 else { cleanupAudio(); target = nil; hotKey.canCancel = false; status = "Recording too short"; return }
        busy = true; status = "Transcribing locally…"
        let job = generation
        let vocabulary = store.data.vocabulary
        defer { busy = false; submitting = false; cleanupAudio(); target = nil; hotKey.canCancel = false }
        do {
            let raw = try await engine.transcribe(url, vocabulary: vocabulary.map(\.phrase))
            guard job == generation else { status = "Cancelled"; return }
            transcript = Vocabulary.apply(vocabulary, to: Transcript.clean(raw))
            guard !transcript.isEmpty else { status = "No speech detected"; return }
            store.record(words: UsageStats.words(in: transcript), duration: duration)
            if autoInsert, let target {
                submitting = true; hotKey.canCancel = false
                status = try await target.insert(transcript)
                hasUnpastedText = false
            } else { status = "Transcript ready to copy" }
        } catch {
            guard job == generation else { status = "Cancelled"; return }
            self.error = error.localizedDescription; status = "Transcript kept in dashboard"
        }
    }
    func cancel() {
        guard !submitting else { return }
        generation += 1; gate.release(); hotKey.canCancel = false
        if recording || starting {
            let wasRecording = recording
            recorder?.stop(); recorder = nil; meter?.invalidate(); meter = nil
            recording = false; starting = false; latched = false; cleanupAudio(); target = nil
            if wasRecording && soundEnabled { sounds.play(.stop) }
        }
        status = busy ? "Cancelling…" : "Cancelled"
    }
    func pasteLast() async {
        guard !transcript.isEmpty && !busy && !recording && !updates.isInstalling else { return }
        error = nil
        guard let app = lastExternalApp, !app.isTerminated else { error = "First focus the app you want to paste into."; return }
        hideDashboard(); app.activate(options: [])
        try? await Task.sleep(for: .milliseconds(200))
        guard let selected = InsertionTarget.capture() else { error = "No destination app found."; return }
        do { status = try await selected.insert(transcript); hasUnpastedText = false } catch { self.error = error.localizedDescription }
    }
    func copy() {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(transcript, forType: .string); status = "Copied"; hasUnpastedText = false
    }
    private func hideDashboard() {
        // Keep the nonactivating recording panel visible while returning focus.
        for window in NSApp.windows where !(window is RecordingPanel) {
            window.orderOut(nil)
        }
    }
    func accessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func shutdown() {
        updates.shutdown(); cancel(); permissionTimer?.invalidate(); hotKey.invalidate()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
    }
    private func cleanupAudio() {
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }; audioURL = nil
    }
}
