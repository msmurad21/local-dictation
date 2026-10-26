import SwiftUI
import Charts
import DictationCore

struct DashboardView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var store: LocalStore
    @State private var tab = "Overview"
    @FocusState private var focusedTab: String?
    @State private var phrase = ""
    @State private var heardAs = ""
    @State private var editingID: UUID?
    private let accent = Color.blue
    private let background = Color(red: 0.055, green: 0.063, blue: 0.08)
    private var sessions: [UsageEntry] { store.data.sessions }
    private var today: [UsageEntry] { sessions.filter { Calendar.current.isDateInToday($0.date) } }
    private var days: [Date] { (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0 - 13, to: Calendar.current.startOfDay(for: Date())) } }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Local").font(.system(size: 19, weight: .semibold))
                        Text("DICTATION").font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(.secondary)
                    }
                }.padding(.bottom, 32)
                ForEach([("Overview", "square.grid.2x2"), ("Vocabulary", "text.book.closed"), ("Controls", "slider.horizontal.3")], id: \.0) { name, icon in
                    SidebarItem(name: name, icon: icon, selected: tab == name, focus: $focusedTab) { tab = name }
                }
                Spacer()
                HStack(spacing: 6) { Circle().fill(controller.recording ? .red : accent).frame(width: 6); Text(controller.recording ? "Recording" : "On-device engine").font(.caption) }
                Text("No cloud. Just your voice.").font(.caption2).foregroundStyle(.secondary)
            }.padding(20).padding(.top, 28).frame(width: 210).background(.white.opacity(0.018))
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if tab == "Overview" { overview }
                    else if tab == "Vocabulary" { vocabulary }
                    else { controls }
                    if let error = controller.error { Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
                    if let error = store.saveError { Text(error).foregroundStyle(.orange) }
                }.padding(32).padding(.top, 20).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
            }
        }.buttonStyle(DashboardButtonStyle()).toggleStyle(.switch).tint(.blue).background(background).preferredColorScheme(.dark).frame(minWidth: 850, minHeight: 650)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tab).font(.system(size: 30, weight: .semibold))
                    Text(tab == "Overview" ? "Your voice, at a glance." : tab == "Vocabulary" ? "Make every word feel familiar." : "Make dictation work your way.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { if controller.recording { controller.finish() } else { controller.toggleRecording() } } label: {
                    Image(systemName: controller.recording ? "stop.fill" : "mic.fill").frame(width: 42, height: 42).background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white)
                }.buttonStyle(.plain).disabled(!controller.ready || controller.busy).help("Start or finish hands-free recording")
            }
            HStack(spacing: 8) {
                Circle().fill(controller.recording ? Color.red : Color.blue).frame(width: 5, height: 5)
                Text(controller.status)
                if controller.busy { ProgressView().controlSize(.mini) }
            }.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).padding(.top, 8)
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                metric("TOTAL WORDS", value: sessions.reduce(0) { $0 + $1.words }.formatted(), caption: "Since you started", icon: "text.alignleft")
                metric("SPEAKING PACE", value: "\(UsageStats.wpm(sessions))", caption: "Words / recording minute", icon: "speedometer")
                metric("TODAY", value: today.reduce(0) { $0 + $1.words }.formatted(), caption: "\(today.count) dictations", icon: "sun.max")
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("Your voice, in motion").font(.headline); Spacer(); Text("LAST 14 DAYS").font(.caption2).tracking(1).foregroundStyle(.secondary) }
                Chart(days, id: \.self) { day in
                    BarMark(x: .value("Day", day, unit: .day), y: .value("Words", UsageStats.dailyWords(sessions, day: day)))
                        .foregroundStyle(accent.gradient).cornerRadius(3)
                }.chartXAxis { AxisMarks(values: .stride(by: .day, count: 3)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()); AxisGridLine() } }
                    .chartYAxis { AxisMarks(position: .leading) }.frame(height: 125)
                if sessions.isEmpty { Text("Your first dictation will bring this chart to life.").font(.caption).foregroundStyle(.secondary) }
            }.card()
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pace over time").font(.headline)
                    Chart(days, id: \.self) { day in
                        let entries = sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                        if !entries.isEmpty {
                            LineMark(x: .value("Day", day), y: .value("WPM", UsageStats.wpm(entries))).foregroundStyle(accent)
                            PointMark(x: .value("Day", day), y: .value("WPM", UsageStats.wpm(entries))).foregroundStyle(accent)
                        }
                    }.chartXAxis(.hidden).frame(height: 72)
                    Text("Recording time includes pauses.").font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 136, alignment: .topLeading).card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time on mic").font(.headline)
                    Text(String(format: "%.1f min", sessions.reduce(0) { $0 + $1.duration } / 60)).font(.system(size: 30, weight: .medium, design: .rounded)).foregroundStyle(accent)
                    Text("\(sessions.count) completed dictations").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 136, alignment: .topLeading).card()
            }
            heatmap
            if !controller.savedRecordings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Recent recordings").font(.headline); Spacer(); Button("Open folder") { controller.revealRecordings() } }
                    Text("Audio stays on this Mac for 24 hours, up to 30 recordings. Failed transcription retries automatically up to 3 times. Retry below to recover a result into this dashboard; it will not paste automatically.").font(.caption).foregroundStyle(.secondary)
                    ForEach(controller.savedRecordings) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.created, style: .date) + Text(" · ") + Text(item.created, style: .time)
                                Text("\(Int(item.duration)) seconds · \(item.state)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Retry") { Task { await controller.retryRecording(item) } }
                            Button("Delete", role: .destructive) { controller.deleteRecording(item) }
                        }.disabled(controller.busy || controller.recording || controller.starting)
                    }
                }.card()
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Latest transcript").font(.headline); Spacer(); Button("Copy") { controller.copy() }.disabled(controller.transcript.isEmpty); Button("Paste in last app") { Task { await controller.pasteLast() } }.disabled(controller.transcript.isEmpty || controller.busy || controller.recording) }
                TextEditor(text: $controller.transcript).font(.body).scrollContentBackground(.hidden).frame(height: 130).disabled(controller.busy)
                if !controller.cleanupNote.isEmpty { Text(controller.cleanupNote).font(.caption).foregroundStyle(.secondary) }
                if !controller.rawTranscript.isEmpty {
                    DisclosureGroup("Original transcript") {
                        Text(controller.rawTranscript).textSelection(.enabled).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                        Button("Use original") { controller.transcript = controller.rawTranscript; controller.cleanupNote = "Original restored" }.disabled(controller.busy)
                    }
                }
                Text("Transcript stays in memory. Recent audio is saved locally for recovery for up to 24 hours.").font(.caption2).foregroundStyle(.secondary)
            }.card()
        }
    }
    private func metric(_ label: String, value: String, caption: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Text(label).font(.system(size: 9, weight: .semibold)).tracking(1); Spacer(); Image(systemName: icon) }.foregroundStyle(.secondary)
            Text(value).font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(accent)
            Text(caption).font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).card()
    }
    private var heatmap: some View {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let sunday = calendar.date(byAdding: .day, value: -(calendar.component(.weekday, from: startOfToday) - 1), to: startOfToday)!
        let start = calendar.date(byAdding: .day, value: -25 * 7, to: sunday)!
        return VStack(alignment: .leading, spacing: 14) {
            HStack { Text("A little every day").font(.headline); Spacer(); Text("26 weeks of dictation").font(.caption).foregroundStyle(.secondary) }
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) { ForEach(["S", "M", "T", "W", "T", "F", "S"].indices, id: \.self) { index in Text(["S", "M", "T", "W", "T", "F", "S"][index]).font(.system(size: 8)).frame(width: 12, height: 12).foregroundStyle(.secondary) } }
                ForEach(0..<26, id: \.self) { week in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { weekday in
                            let date = calendar.date(byAdding: .day, value: week * 7 + weekday, to: start)!
                            let words = UsageStats.dailyWords(sessions, day: date)
                            RoundedRectangle(cornerRadius: 3).fill(words == 0 ? Color.white.opacity(0.055) : accent.opacity(words < 100 ? 0.3 : words < 500 ? 0.55 : words < 1000 ? 0.8 : 1))
                                .frame(maxWidth: .infinity).frame(height: 12).opacity(date > startOfToday ? 0.2 : 1)
                                .help("\(date.formatted(date: .abbreviated, time: .omitted)): \(words) words")
                                .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)), \(words) words")
                        }
                    }
                }
            }
            HStack(spacing: 4) { Text("Less"); ForEach([0.05, 0.3, 0.55, 0.8, 1.0], id: \.self) { opacity in RoundedRectangle(cornerRadius: 2).fill(accent.opacity(opacity)).frame(width: 10, height: 10) }; Text("More"); Spacer(); Text("Real usage only · no historical estimates") }.font(.system(size: 9)).foregroundStyle(.secondary)
        }.card()
    }
    private var vocabulary: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Give names, technical terms, and unusual words a better chance. Vocabulary is supplied as a local transcription hint; it does not retrain the model.").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 14) {
                Text(editingID == nil ? "Add to your vocabulary" : "Edit vocabulary").font(.headline)
                TextField("Preferred word or phrase — e.g. Kubernetes", text: $phrase).textFieldStyle(.plain).padding(12).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                TextField("Often heard as — optional exact correction", text: $heardAs).textFieldStyle(.plain).padding(12).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                Text("An optional correction replaces matching words after transcription. Leave it blank to use only a recognition hint.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(editingID == nil ? "Add word" : "Save changes") {
                        if let editingID { store.remove(editingID) }
                        store.add(phrase: phrase, heardAs: heardAs)
                        phrase = ""; heardAs = ""; editingID = nil
                    }.buttonStyle(DashboardButtonStyle(primary: true)).disabled(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if editingID != nil { Button("Cancel edit") { editingID = nil; phrase = ""; heardAs = "" } }
                    Spacer(); Text("\(store.data.vocabulary.count) entries").font(.caption).foregroundStyle(.secondary)
                }
            }.card()
            ForEach(store.data.vocabulary) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.phrase).font(.headline)
                        Text(entry.heardAs.isEmpty ? "Recognition hint" : "\(entry.heardAs) → \(entry.phrase)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { editingID = entry.id; phrase = entry.phrase; heardAs = entry.heardAs }
                    Button { store.remove(entry.id) } label: { Image(systemName: "trash") }.help("Remove vocabulary entry")
                }.card()
            }
            if store.data.vocabulary.isEmpty { Label("Your dictionary is ready for its first word.", systemImage: "text.book.closed").foregroundStyle(.secondary).padding(.top, 20) }
        }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recording mode").font(.headline)
                Picker("Fn key behavior", selection: $controller.mode) {
                    ForEach(RecordingMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).disabled(controller.recording || controller.starting)
                Text(controller.mode == .pushToTalk ? "Hold Fn to speak. Release to transcribe and paste." : "Tap Fn to start. Tap Fn again to finish.").font(.callout)
                Label("Fn + Space starts hands-free recording. Press Fn once to finish.", systemImage: "keyboard").font(.callout).foregroundStyle(.secondary)
                Text("Fallback: Control–Option–Space follows your selected mode. Escape or × cancels; ✓ finishes. Recordings stop automatically after 10 minutes.").font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 16) {
                    Text("Set macOS’s “Press 🌐 key to” action to “Do Nothing” so finishing a recording does not open emoji. Other apps using Fn may still conflict.").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Keyboard settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) }
                }
            }.card()
            VStack(alignment: .leading, spacing: 16) {
                Text("Background & insertion").font(.headline)
                Toggle("Show floating recording control", isOn: $controller.showOverlay)
                Toggle("Subtle start and stop sounds", isOn: $controller.soundEnabled)
                Text("Drag the small control to any screen edge. Right-click it to choose an edge or open the dashboard. Closing this window keeps dictation running in the menu bar.").font(.caption).foregroundStyle(.secondary)
                Toggle("Automatically paste into the focused app", isOn: $controller.autoInsert)
                Text("If you change apps or windows while processing, the transcript stays here. Clipboard contents are restored after pasting when no other app has changed them.").font(.caption).foregroundStyle(.secondary)
            }.card()
            VStack(alignment: .leading, spacing: 12) {
                Text("Smart cleanup").font(.headline)
                Toggle("Clean up before pasting", isOn: $controller.cleanupEnabled).disabled(controller.busy)
                Text("Fix spelling and grammar, remove filler words, and infer lists, ordered steps, headings and paragraphs while preserving your meaning.").font(.callout)
                Text(controller.cleanupAvailability).font(.caption).foregroundStyle(.secondary)
                Text("Runs entirely on this Mac using Apple Intelligence. If cleanup is unavailable or fails, the original transcript is used. You can compare and restore the original in Overview.").font(.caption).foregroundStyle(.secondary)
            }.card()
            UpdateSettingsView(updates: controller.updates).card()
            VStack(alignment: .leading, spacing: 12) {
                Text("Permissions & engine").font(.headline)
                Label(controller.accessibilityReady ? "Accessibility is enabled" : "Accessibility is required for automatic paste", systemImage: controller.accessibilityReady ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(controller.accessibilityReady ? accent : .orange)
                Label(controller.fnReady ? "Fn shortcuts connected" : "Fn shortcuts unavailable — use the fallback shortcut", systemImage: "keyboard").font(.callout)
                Button("Open Accessibility settings") { controller.accessibility() }
                if !controller.ready { Button("Download / repair speech model") { Task { await controller.prepareModel() } }.disabled(controller.busy) }
                Text("Multilingual Whisper Base · fully local inference").font(.caption).foregroundStyle(.secondary)
            }.card()
        }
    }
}

private extension View {
    func card() -> some View { self.padding(22).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18)) }
}

private struct SidebarItem: View {
    let name: String
    let icon: String
    let selected: Bool
    let focus: FocusState<String?>.Binding
    let action: () -> Void
    private var focused: Bool { focus.wrappedValue == name }
    @State private var hovered = false
    var body: some View {
        Button { action(); focus.wrappedValue = name } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15)).frame(width: 20)
                Text(name).font(.system(size: 13, weight: selected ? .semibold : .medium))
                Spacer()
            }.padding(.horizontal, 14).frame(height: 44)
                .foregroundStyle(selected ? Color.blue : Color.secondary)
                .background(selected ? Color.blue.opacity(0.10) : Color.white.opacity(hovered ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(focused ? 1 : selected ? 0.45 : 0), lineWidth: focused ? 2 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).focused(focus, equals: name).focusEffectDisabled()
            .onHover { hovered = $0 }.accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct DashboardButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        DashboardButtonBody(configuration: configuration, primary: primary)
    }
    private struct DashboardButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let primary: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hovered = false
        var body: some View {
            configuration.label.font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(primary ? Color.white : configuration.role == .destructive ? Color.red : Color.primary)
                .background(primary ? Color.blue : Color.white.opacity(hovered ? 0.10 : 0.055), in: RoundedRectangle(cornerRadius: 9))
                .opacity(!enabled ? 0.35 : configuration.isPressed ? 0.65 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 9))
                .onHover { hovered = $0 }
        }
    }
}
