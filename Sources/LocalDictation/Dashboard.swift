import SwiftUI
import Charts
import DictationCore

struct DashboardView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var store: LocalStore
    @State private var tab = "Overview"
    @State private var phrase = ""
    @State private var heardAs = ""
    @State private var editingID: UUID?
    private let green = Color(red: 0.64, green: 0.91, blue: 0.57)
    private let background = Color(red: 0.055, green: 0.067, blue: 0.065)
    private var sessions: [UsageEntry] { store.data.sessions }
    private var today: [UsageEntry] { sessions.filter { Calendar.current.isDateInToday($0.date) } }
    private var days: [Date] { (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0 - 13, to: Calendar.current.startOfDay(for: Date())) } }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: "waveform").foregroundStyle(green); Text("LOCAL").tracking(3).fontWeight(.black) }.font(.title3).padding(.bottom, 32)
                ForEach([("Overview", "square.grid.2x2"), ("Vocabulary", "text.book.closed"), ("Controls", "slider.horizontal.3")], id: \.0) { name, icon in
                    Button { tab = name } label: {
                        Label(name, systemImage: icon).font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(tab == name ? green.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(tab == name ? green : .secondary)
                    }.buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 6) { Circle().fill(controller.recording ? .red : green).frame(width: 6); Text(controller.recording ? "Recording" : "On-device engine").font(.caption) }
                Text("No cloud. Just your voice.").font(.caption2).foregroundStyle(.secondary)
            }.padding(24).padding(.top, 24).frame(width: 205).background(.white.opacity(0.025))
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if tab == "Overview" { overview }
                    else if tab == "Vocabulary" { vocabulary }
                    else { controls }
                    if let error = controller.error { Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
                    if let error = store.saveError { Text(error).foregroundStyle(.orange) }
                }.padding(30).padding(.top, 22)
            }
        }.background(background).preferredColorScheme(.dark).frame(minWidth: 850, minHeight: 650)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tab == "Overview" ? "Make room for your thoughts." : tab == "Vocabulary" ? "Words that sound like you." : "Your voice, your controls.").font(.system(size: 29, weight: .semibold, design: .rounded))
                Spacer()
                Button { if controller.recording { controller.finish() } else { controller.toggleRecording() } } label: {
                    Image(systemName: controller.recording ? "stop.fill" : "mic.fill").padding(10).background(green, in: Circle()).foregroundStyle(.black)
                }.buttonStyle(.plain).disabled(!controller.ready || controller.busy).help("Start or finish hands-free recording")
            }
            HStack { Text(controller.status); if controller.busy { ProgressView().controlSize(.mini) } }.font(.callout).foregroundStyle(.secondary)
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
                        .foregroundStyle(green.gradient).cornerRadius(3)
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
                            LineMark(x: .value("Day", day), y: .value("WPM", UsageStats.wpm(entries))).foregroundStyle(green)
                            PointMark(x: .value("Day", day), y: .value("WPM", UsageStats.wpm(entries))).foregroundStyle(green)
                        }
                    }.chartXAxis(.hidden).frame(height: 72)
                    Text("Recording time includes pauses.").font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time on mic").font(.headline)
                    Text(String(format: "%.1f min", sessions.reduce(0) { $0 + $1.duration } / 60)).font(.system(size: 30, weight: .medium, design: .rounded)).foregroundStyle(green)
                    Text("\(sessions.count) completed dictations").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).card()
            }
            heatmap
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Latest transcript").font(.headline); Spacer(); Button("Copy") { controller.copy() }.disabled(controller.transcript.isEmpty); Button("Paste in last app") { Task { await controller.pasteLast() } }.disabled(controller.transcript.isEmpty || controller.busy || controller.recording) }
                TextEditor(text: $controller.transcript).font(.body).scrollContentBackground(.hidden).frame(height: 90)
                Text("Transcript stays in memory. Only word counts, durations, and dates are saved.").font(.caption2).foregroundStyle(.secondary)
            }.card()
        }
    }
    private func metric(_ label: String, value: String, caption: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Text(label).font(.system(size: 9, weight: .semibold)).tracking(1); Spacer(); Image(systemName: icon) }.foregroundStyle(.secondary)
            Text(value).font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(green)
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
                            RoundedRectangle(cornerRadius: 3).fill(words == 0 ? Color.white.opacity(0.055) : green.opacity(words < 100 ? 0.3 : words < 500 ? 0.55 : words < 1000 ? 0.8 : 1))
                                .frame(maxWidth: .infinity).frame(height: 12).opacity(date > startOfToday ? 0.2 : 1)
                                .help("\(date.formatted(date: .abbreviated, time: .omitted)): \(words) words")
                                .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)), \(words) words")
                        }
                    }
                }
            }
            HStack(spacing: 4) { Text("Less"); ForEach([0.05, 0.3, 0.55, 0.8, 1.0], id: \.self) { opacity in RoundedRectangle(cornerRadius: 2).fill(green.opacity(opacity)).frame(width: 10, height: 10) }; Text("More"); Spacer(); Text("Real usage only · no historical estimates") }.font(.system(size: 9)).foregroundStyle(.secondary)
        }.card()
    }
    private var vocabulary: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Give names, technical terms, and unusual words a better chance. Vocabulary is supplied as a local transcription hint; it does not retrain the model.").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 14) {
                Text(editingID == nil ? "Add to your vocabulary" : "Edit vocabulary").font(.headline)
                TextField("Preferred word or phrase — e.g. Kubernetes", text: $phrase).textFieldStyle(.roundedBorder)
                TextField("Often heard as — optional exact correction", text: $heardAs).textFieldStyle(.roundedBorder)
                Text("An optional correction replaces matching words after transcription. Leave it blank to use only a recognition hint.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(editingID == nil ? "Add word" : "Save changes") {
                        if let editingID { store.remove(editingID) }
                        store.add(phrase: phrase, heardAs: heardAs)
                        phrase = ""; heardAs = ""; editingID = nil
                    }.buttonStyle(.borderedProminent).tint(green).foregroundStyle(.black).disabled(phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Text("If the Globe key opens emoji or changes input language, set its action to “Do Nothing” in macOS Keyboard settings. Other apps using Fn, including Wispr Flow, may conflict.").font(.caption).foregroundStyle(.secondary)
            }.card()
            VStack(alignment: .leading, spacing: 16) {
                Text("Background & insertion").font(.headline)
                Toggle("Show floating recording control", isOn: $controller.showOverlay)
                Toggle("Subtle start and stop sounds", isOn: $controller.soundEnabled)
                Text("Drag the small control to any screen edge. Right-click it to choose an edge or open the dashboard. Closing this window keeps dictation running in the menu bar.").font(.caption).foregroundStyle(.secondary)
                Toggle("Automatically paste into the focused app", isOn: $controller.autoInsert)
                Text("If you change apps or windows while processing, the transcript stays here. Clipboard contents are restored after pasting when no other app has changed them.").font(.caption).foregroundStyle(.secondary)
            }.card()
            UpdateSettingsView(updates: controller.updates).card()
            VStack(alignment: .leading, spacing: 12) {
                Text("Permissions & engine").font(.headline)
                Label(controller.accessibilityReady ? "Accessibility is enabled" : "Accessibility is required for automatic paste", systemImage: controller.accessibilityReady ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(controller.accessibilityReady ? green : .orange)
                Label(controller.fnReady ? "Fn shortcuts connected" : "Fn shortcuts unavailable — use the fallback shortcut", systemImage: "keyboard").font(.callout)
                Button("Open Accessibility settings") { controller.accessibility() }
                if !controller.ready { Button("Download / repair speech model") { Task { await controller.prepareModel() } }.disabled(controller.busy) }
                Text("Multilingual Whisper Base · fully local inference").font(.caption).foregroundStyle(.secondary)
            }.card()
        }
    }
}

private extension View {
    func card() -> some View { self.padding(18).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06))) }
}
