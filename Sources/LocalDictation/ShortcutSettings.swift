import SwiftUI

struct ShortcutSettings: View {
    @ObservedObject var controller: DictationController
    @State private var hold = UInt32(UserDefaults.standard.object(forKey: "holdCode") as? Int ?? 49)
    @State private var holdMods = UInt32(UserDefaults.standard.object(forKey: "holdModifiers") as? Int ?? 6144)
    @State private var toggle = UInt32(UserDefaults.standard.object(forKey: "toggleCode") as? Int ?? 15)
    @State private var toggleMods = UInt32(UserDefaults.standard.object(forKey: "toggleModifiers") as? Int ?? 6144)
    @State private var useFn = UserDefaults.standard.object(forKey: "fnEnabled") as? Bool ?? true
    @State private var saved = false
    private let keys: [(String, UInt32)] = [("Space",49),("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),("N",45),("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),("V",9),("W",13),("X",7),("Y",16),("Z",6),("F5",96),("F6",97),("F7",98),("F8",100),("F9",101),("F10",109),("F11",103),("F12",111)]
    private let modifiers: [(String, UInt32)] = [("Control + Option",6144),("Control + Shift",4608),("Command + Shift",768),("Command + Option",2304),("Control + Option + Shift",6656)]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keyboard shortcuts").font(.headline)
            row("Push to talk", code: $hold, mods: $holdMods)
            row("Hands-free", code: $toggle, mods: $toggleMods)
            Toggle("Also use Fn and Fn + Space", isOn: $useFn)
            Text("Hold push-to-talk to record; release to finish. Press hands-free once to start and again to finish. Changes take effect when saved. System or other-app shortcut conflicts may require a different combination.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Save shortcuts") { saved = controller.saveShortcuts(hold: hold, holdMods: holdMods, toggle: toggle, toggleMods: toggleMods, useFn: useFn) }
                Button("Reset defaults") { hold = 49; holdMods = 6144; toggle = 15; toggleMods = 6144; useFn = true; saved = false }
                if saved { Label("Saved", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.blue) }
            }
        }.disabled(controller.recording || controller.starting || controller.busy)
            .onChange(of: hold) { _, _ in saved = false }.onChange(of: holdMods) { _, _ in saved = false }
            .onChange(of: toggle) { _, _ in saved = false }.onChange(of: toggleMods) { _, _ in saved = false }
            .onChange(of: useFn) { _, _ in saved = false }
    }
    private func row(_ title: String, code: Binding<UInt32>, mods: Binding<UInt32>) -> some View {
        HStack {
            Text(title).frame(width: 95, alignment: .leading)
            Picker(title + " modifiers", selection: mods) { ForEach(modifiers, id: \.1) { Text($0.0).tag($0.1) } }.labelsHidden()
            Picker(title + " key", selection: code) { ForEach(keys, id: \.1) { Text($0.0).tag($0.1) } }.labelsHidden().frame(width: 100)
        }
    }
}
