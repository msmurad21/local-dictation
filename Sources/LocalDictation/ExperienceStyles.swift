import SwiftUI
import AppKit
import Charts
import DictationCore

struct ExperienceToggle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 16) {
                configuration.label.foregroundStyle(.primary)
                Spacer()
                Capsule().fill(configuration.isOn ? Color.blue : .white.opacity(0.12)).frame(width: 38, height: 23)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) { Circle().fill(.white).frame(width: 17, height: 17).padding(3) }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).animation(.easeOut(duration: 0.15), value: configuration.isOn)
            .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

struct AppsExperience: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var store: LocalStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.click.2").font(.title2).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Right where your cursor is").font(.headline)
                    Text("Your focused field identifies the destination. Its words stay private.").font(.callout).foregroundStyle(.secondary)
                }
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            let apps = (store.data.apps ?? []).sorted { $0.words == $1.words ? $0.name < $1.name : $0.words > $1.words }
            let events = store.data.appEvents ?? []
            let totalWords = apps.reduce(0) { $0 + $1.words }
            HStack(spacing: 12) {
                metric("APPS", value: "\(apps.count)")
                metric("DICTATIONS", value: apps.reduce(0) { $0 + $1.dictations }.formatted())
                metric("WORDS", value: totalWords.formatted())
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("Your voice, across apps").font(.headline); Spacer(); Text("LAST 14 DAYS").font(.caption2).foregroundStyle(.secondary) }
                let days = (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0 - 13, to: Calendar.current.startOfDay(for: Date())) }
                Chart(days, id: \.self) { day in
                    BarMark(x: .value("Day", day, unit: .day), y: .value("Words", events.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.words }))
                        .foregroundStyle(Color.blue.gradient).cornerRadius(4)
                }.chartXAxis { AxisMarks(values: .stride(by: .day, count: 3)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                    .frame(height: 140)
                Text("Daily activity and recording time start with this update. Earlier app totals are preserved.").font(.caption).foregroundStyle(.secondary)
            }.padding(22).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
            if !apps.isEmpty { Text("Where your words go").font(.title3.weight(.semibold)) }
            if apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 36)).foregroundStyle(.blue)
                    Text("Your voice belongs everywhere").font(.title3)
                    Text("Apps appear here after you dictate and paste into them. Tracking starts with this update.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 36)
            }
            ForEach(apps) { app in
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 42, height: 42) }
                        else { Image(systemName: "app.fill").font(.largeTitle).foregroundStyle(.blue) }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(app.name).font(.headline)
                            Text("Last used " + app.lastUsed.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(totalWords > 0 ? Int((Double(app.words) / Double(totalWords) * 100).rounded()) : 0)% of words").font(.caption.weight(.medium)).foregroundStyle(.blue)
                    }
                    GeometryReader { geometry in
                        Capsule().fill(.white.opacity(0.06))
                            .overlay(alignment: .leading) { Capsule().fill(Color.blue.gradient).frame(width: geometry.size.width * (totalWords > 0 ? Double(app.words) / Double(totalWords) : 0)) }
                    }.frame(height: 5)
                    HStack {
                        detail("Dictations", value: app.dictations.formatted())
                        Spacer()
                        detail("Words", value: app.words.formatted())
                        Spacer()
                        detail("Recording time", value: AppUsage.durationLabel(app.duration))
                    }
                }.padding(22).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
            }
            AppContextSettings(controller: controller).padding(22).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        }
    }
    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            Text(value).font(.system(size: 28, weight: .semibold, design: .rounded))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    }
    private func detail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(value).font(.headline); Text(title).font(.caption).foregroundStyle(.secondary) }
    }

}
