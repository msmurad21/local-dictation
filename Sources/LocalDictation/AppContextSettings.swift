import SwiftUI

struct AppContextSettings: View {
    @ObservedObject var controller: DictationController
    @State private var terms = ""
    @State private var saved = false
    private var bundleID: String { controller.lastExternalApp?.bundleIdentifier ?? "" }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last recording target: " + controller.capturedContext).font(.caption).foregroundStyle(.secondary)
            Text("App vocabulary: " + (controller.lastExternalApp?.localizedName ?? "Switch to your target app first")).font(.subheadline)
            TextField("Jargon for this app, separated by commas", text: $terms)
                .textFieldStyle(.roundedBorder).onChange(of: terms) { _ in saved = false }
            HStack {
                Button("Save app vocabulary") { controller.saveAppVocabulary(bundleID: bundleID, terms: terms); saved = true }
                    .disabled(bundleID.isEmpty || controller.recording || controller.busy)
                if saved { Text("Saved").font(.caption).foregroundStyle(.secondary) }
            }
            Text("Switch to the app you dictate into, then return here to teach its terminology. These spellings are used only for that app; global Vocabulary still applies everywhere.").font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { terms = controller.appVocabulary[bundleID] ?? "" }
        .onChange(of: bundleID) { id in terms = controller.appVocabulary[id] ?? ""; saved = false }
    }
}
