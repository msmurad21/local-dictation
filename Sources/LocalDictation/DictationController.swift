import AppKit
import AVFoundation
import DictationCore

@MainActor final class DictationController: ObservableObject {
    @Published var status = "Loading local model…"
    @Published var transcript = "" { didSet { hasUnpastedText = !transcript.isEmpty } }
    @Published var rawTranscript = ""
    @Published var cleanupNote = ""
    @Published var cleanupAvailability = TranscriptProcessor.availability
    @Published var cleanupEnabled = UserDefaults.standard.object(forKey: "cleanupEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(cleanupEnabled, forKey: "cleanupEnabled") }
    }
    @Published var contextEnabled = UserDefaults.standard.object(forKey: "contextEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(contextEnabled, forKey: "contextEnabled") }
    }
    @Published var savedRecordings: [SavedRecording] = []
    private var archive: RecordingArchive?
    private var activeRecording: SavedRecording?
    private var shuttingDown = false
    private var speechTask: Task<String, Error>?
    private let processor = TranscriptProcessor()
    private var polishTask: Task<PolishedTranscript, Error>?
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
    @Published var fnShortcutsEnabled = UserDefaults.standard.object(forKey: "fnEnabled") as? Bool ?? true
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
    private var transcriptRecordingID: UUID?
    private var transcriptDuration: Double?
    private var meter: Timer?
    private var permissionTimer: Timer?
    private var retentionTimer: Timer?
    private var generation = 0
    private var workspaceObserver: NSObjectProtocol?
    @Published private(set) var lastExternalApp: NSRunningApplication?
    @Published var capturedContext = "No recording yet"
    var appVocabulary: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "appVocabulary") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "appVocabulary") }
    }
    func saveAppVocabulary(bundleID: String, terms: String) {
        var profiles = appVocabulary
        profiles[bundleID] = AppDictationContext.parseTerms(terms).joined(separator: ", ")
        appVocabulary = profiles
    }
    var showDashboard: (() -> Void)?

    init() {
        do {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LocalDictation/Recordings")
            archive = try RecordingArchive(root: root)
            try archive?.prune()
            savedRecordings = archive?.recordings() ?? []
        } catch { self.error = "Recording recovery could not open: " + error.localizedDescription }
        lastExternalApp = NSWorkspace.shared.frontmostApplication
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in self?.lastExternalApp = app }
        }
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.busy, !self.recording, !self.starting else { return }
                do { try self.archive?.prune(); self.savedRecordings = self.archive?.recordings() ?? [] }
                catch { self.error = "Recording retention cleanup failed: " + error.localizedDescription }
            }
        }
        // Fn is always hold-to-talk; hands-free is Fn + Space.
        mode = .pushToTalk
        fnShortcutsEnabled = true
        UserDefaults.standard.set(true, forKey: "fnEnabled")
        hotKey.fnEnabled = true
        if !UserDefaults.standard.bool(forKey: "recordedShortcutsV1") {
            for key in ["holdCode", "toggleCode"] { UserDefaults.standard.set(Int(UInt32.max), forKey: key) }
            try? hotKey.configure(hold: .max, holdMods: 0, toggle: .max, toggleMods: 0, useFn: true)
            UserDefaults.standard.set(true, forKey: "recordedShortcutsV1")
        }
        hotKey.mode = .pushToTalk
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
                self.cleanupAvailability = TranscriptProcessor.availability
                self.hotKey.refreshFn(); self.fnReady = self.hotKey.fnAvailable
            }
        }
        Task {
            busy = true
            do { try await engine.load(); ready = true; status = "Ready to dictate" }
            catch { status = "Model not ready"; self.error = error.localizedDescription }
            busy = false
            if ready {
                let recoveryGeneration = generation
                for item in savedRecordings.reversed() where item.state == "pending" {
                    guard generation == recoveryGeneration else { break }
                    await retryRecording(item)
                }
            }
        }
    }
    func captureShortcut(_ active: Bool) { do { try hotKey.setCapture(active) } catch { self.error = error.localizedDescription } }
    func saveShortcuts(hold: UInt32, holdMods: UInt32, toggle: UInt32, toggleMods: UInt32, useFn: Bool) -> Bool {
        guard !recording && !busy && !starting else { return false }
        do {
            try hotKey.configure(hold: hold, holdMods: holdMods, toggle: toggle, toggleMods: toggleMods, useFn: useFn)
            fnReady = hotKey.fnAvailable; fnShortcutsEnabled = useFn; error = nil; status = "Shortcuts saved"; return true
        } catch { self.error = error.localizedDescription; return false }
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
            guard let archive else { throw AppError.message("Local recording recovery is unavailable. Restart the app or check available disk space.") }
            try archive.prune()
            var item = try archive.create()
            item.context = contextEnabled ? selectedTarget?.context : nil
            if contextEnabled, let selectedTarget {
                item.appContext = AppDictationContext(appName: selectedTarget.appName, bundleID: selectedTarget.bundleID, customTerms: appVocabulary[selectedTarget.bundleID] ?? "")
            }
            capturedContext = item.appContext.map { "\($0.appName) · \($0.bundleID)" } ?? "App context off or target unavailable"
            try archive.save(item)
            activeRecording = item
            let url = archive.audioURL(item)
            audioURL = url
            let capture = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: Int(kAudioFormatLinearPCM), AVSampleRateKey: 16000.0, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
            capture.isMeteringEnabled = true
            guard capture.record() else { throw AppError.message("The microphone could not start recording.") }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            recorder = capture; target = selectedTarget; recording = true; starting = false; elapsed = 0
            levels = Array(repeating: 0.03, count: 28)
            hotKey.canCancel = true
            if soundEnabled { sounds.play(.start) }
            status = latched ? "Hands-free recording" : "Listening · release Fn to finish"
            meter = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let recorder = self.recorder else { return }
                    recorder.updateMeters()
                    let value = max(0.03, min(1, pow(max(0, min(1, (recorder.averagePower(forChannel: 0) + 55) / 45)), 0.7)))
                    self.levels.removeFirst(); self.levels.append(value)
                    self.elapsed = recorder.currentTime
                    if self.elapsed >= 600 || !recorder.isRecording { await self.stop() }
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
        guard var item = activeRecording, let archive else { return }
        item.duration = duration
        do { try archive.save(item) } catch { self.error = "Could not save recovery metadata: " + error.localizedDescription }
        audioURL = nil; activeRecording = nil
        let destination = target; target = nil
        await processRecording(item, url: url, destination: destination)
    }
    func retryRecording(_ item: SavedRecording) async {
        guard ready && !busy && !recording && !starting && !updates.isInstalling, let archive else { return }
        // A retry may happen after focus changed or after restarting. Never auto-paste it.
        var recovered = item
        if recovered.duration == 0, let file = try? AVAudioFile(forReading: archive.audioURL(item)) {
            recovered.duration = Double(file.length) / file.processingFormat.sampleRate
        }
        await processRecording(recovered, url: archive.audioURL(item), destination: nil)
    }
    func deleteRecording(_ item: SavedRecording) {
        guard !busy && !recording && !starting else { return }
        do { try archive?.remove(item); savedRecordings = archive?.recordings() ?? [] }
        catch { self.error = error.localizedDescription }
    }
    func revealRecordings() {
        if let archive { NSWorkspace.shared.open(archive.root) }
    }
    private func processRecording(_ saved: SavedRecording, url: URL, destination: InsertionTarget?) async {
        busy = true; error = nil; hotKey.canCancel = true
        var item = saved
        let job = generation
        let vocabulary = store.data.vocabulary
        let appContext = contextEnabled ? saved.appContext : nil
        let hints = vocabulary.map(\.phrase) + (appContext?.terms ?? [])
        capturedContext = appContext.map { "\($0.appName) · \($0.bundleID)" } ?? "General context"
        defer {
            busy = false; submitting = false; polishTask = nil; speechTask = nil; hotKey.canCancel = false
            savedRecordings = archive?.recordings() ?? []
        }
        do {
            var raw = ""
            // Bound retries. A failed recording remains available for a later manual retry.
            for attempt in 1...3 {
                guard job == generation else { throw CancellationError() }
                status = attempt == 1 ? "Transcribing locally…" : "Retrying local transcription (\(attempt)/3)…"
                do {
                    let task = Task { try await engine.transcribe(url, vocabulary: hints) }
                    speechTask = task
                    raw = try await task.value
                    break
                } catch {
                    guard job == generation else { throw CancellationError() }
                    if attempt == 3 { throw error }
                    try await Task.sleep(for: .milliseconds(400))
                }
            }
            guard job == generation else { throw CancellationError() }
            let original = Vocabulary.apply(vocabulary, to: Transcript.clean(raw))
            guard !original.isEmpty else {
                item.state = "no speech"; try archive?.save(item)
                status = "No speech detected · recording saved for retry"; return
            }
            // Make decoded speech available even if later cleanup or insertion fails.
            transcriptRecordingID = item.id; transcriptDuration = item.duration
            rawTranscript = original; transcript = original; cleanupNote = "Original transcript"
            var result = PolishedTranscript(text: original, note: "Cleanup off · original transcript")
            if cleanupEnabled {
                status = "Cleaning up locally…"
                let task = Task { try await processor.process(original, vocabulary: hints, context: contextEnabled ? (saved.context ?? .general) : .general, appContext: appContext) }
                polishTask = task
                result = try await task.value
            }
            guard job == generation else { throw CancellationError() }
            cleanupNote = result.note
            transcript = Vocabulary.apply(vocabulary, to: result.text)
            if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                item.state = "completed"; try archive?.save(item)
                status = "Dictation cleared by spoken command"; return
            }
            let shouldCount = !item.counted
            item.state = "completed"; item.counted = true
            try archive?.save(item)
            if shouldCount { store.record(words: UsageStats.words(in: original), duration: item.duration) }
            if autoInsert, let destination {
                submitting = true; hotKey.canCancel = false
                status = try await destination.insert(transcript)
                store.recordApp(name: destination.appName, bundleID: destination.bundleID, words: UsageStats.words(in: transcript), duration: transcriptDuration, recordingID: transcriptRecordingID)
                hasUnpastedText = false
            } else { status = "Transcript ready to copy · recording saved for 24 hours" }
        } catch {
            if job != generation {
                // Explicit cancellation discards audio and must not resume at next launch.
                if !shuttingDown { try? archive?.remove(item) }; status = "Cancelled"; return
            }
            if item.state != "completed" { item.state = "failed"; try? archive?.save(item) }
            self.error = error.localizedDescription
            status = "Recording saved · retry from Overview"
        }
    }
    func cancel() {
        guard !submitting else { return }
        generation += 1; gate.release(); speechTask?.cancel(); polishTask?.cancel(); hotKey.canCancel = false
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
        do { status = try await selected.insert(transcript); store.recordApp(name: selected.appName, bundleID: selected.bundleID, words: UsageStats.words(in: transcript), duration: transcriptDuration, recordingID: transcriptRecordingID); hasUnpastedText = false } catch { self.error = error.localizedDescription }
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
        shuttingDown = true
        if var item = activeRecording {
            item.duration = recorder?.currentTime ?? elapsed
            recorder?.stop(); recorder = nil
            try? archive?.save(item)
            activeRecording = nil; audioURL = nil
        }
        updates.shutdown(); cancel(); permissionTimer?.invalidate(); retentionTimer?.invalidate(); hotKey.invalidate()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
    }
    private func cleanupAudio() {
        if let activeRecording { try? archive?.remove(activeRecording) }
        else if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        audioURL = nil; activeRecording = nil
        savedRecordings = archive?.recordings() ?? []
    }
}
