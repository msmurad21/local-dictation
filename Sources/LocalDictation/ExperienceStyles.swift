import SwiftUI
import AppKit

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
            let apps = (store.data.apps ?? []).sorted { $0.lastUsed > $1.lastUsed }
            if apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 36)).foregroundStyle(.blue)
                    Text("Your voice belongs everywhere").font(.title3)
                    Text("Apps appear here after you dictate and paste into them. Tracking starts with this update.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 36)
            }
            ForEach(apps) { app in
                HStack(spacing: 16) {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 42, height: 42) }
                    else { Image(systemName: "app.fill").font(.largeTitle).foregroundStyle(.blue) }
                    VStack(alignment: .leading, spacing: 5) { Text(app.name).font(.headline); Text("\(app.dictations) dictations · \(app.words) words").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(app.lastUsed, style: .relative).font(.caption).foregroundStyle(.secondary)
                }.padding(20).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
            }
            AppContextSettings(controller: controller).padding(22).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
