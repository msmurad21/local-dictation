import SwiftUI
import AppKit
import Carbon

struct ShortcutSettings: View {
    @ObservedObject var controller: DictationController
    @State private var listening: String?
    @State private var monitor: Any?
    @State private var message = ""
    @State private var revision = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("A shortcut to your thoughts").font(.system(size: 22, weight: .semibold))
            Text("Hold to speak. Let go to send. Or go hands-free.").foregroundStyle(.secondary)
            row("Push to talk", detail: "Hold while speaking", kind: "hold", fallback: "fn")
            row("Hands-free", detail: "Press to start or finish", kind: "toggle", fallback: "fn  +  space")
            if listening != nil {
                HStack { Text("Press a combination with ⌘, ⌥ or ⌃. Escape cancels.").font(.caption); Spacer(); Button("Cancel") { stop() } }
            }
            if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
            Text("Fn and Fn + Space always work. Press Fn once to finish hands-free recording.").font(.caption).foregroundStyle(.secondary)
        }.onDisappear { stop() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in stop() }
        .disabled(controller.recording || controller.busy || controller.starting)
    }
    private func row(_ title: String, detail: String, kind: String, fallback: String) -> some View {
        let code = UserDefaults.standard.object(forKey: kind + "Code") as? Int ?? Int(UInt32.max)
        let custom = code != Int(UInt32.max)
        return HStack {
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Text(fallback).font(.system(size: 13, weight: .medium, design: .rounded)).padding(.horizontal, 14).padding(.vertical, 9).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            Button(listening == kind ? "Listening…" : custom ? UserDefaults.standard.string(forKey: kind + "Label") ?? "Custom shortcut" : "Record shortcut") { begin(kind) }
            if custom { Button { reset(kind) } label: { Image(systemName: "arrow.counterclockwise") }.help("Remove custom shortcut") }
        }.id(revision)
    }
    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; listening = nil; controller.captureShortcut(false)
    }
    private func begin(_ kind: String) {
        stop(); message = ""; listening = kind; controller.captureShortcut(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }
            guard !event.isARepeat else { return nil }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.intersection([.command, .option, .control]).isEmpty, !flags.contains(.function) else {
                message = "Add Command, Option or Control to your shortcut."; return nil
            }
            var mods: UInt32 = 0
            if flags.contains(.command) { mods |= UInt32(cmdKey) }
            if flags.contains(.option) { mods |= UInt32(optionKey) }
            if flags.contains(.control) { mods |= UInt32(controlKey) }
            if flags.contains(.shift) { mods |= UInt32(shiftKey) }
            let key = event.keyCode == 49 ? "Space" : (event.charactersIgnoringModifiers ?? "Key \(event.keyCode)").uppercased()
            let label = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "") + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + key
            stop()
            if save(kind, code: UInt32(event.keyCode), mods: mods) { UserDefaults.standard.set(label, forKey: kind + "Label"); revision += 1; message = "Shortcut ready." }
            return nil
        }
    }
    private func save(_ kind: String, code: UInt32, mods: UInt32) -> Bool {
        let d = UserDefaults.standard
        let other = kind == "hold" ? "toggle" : "hold"
        let otherCode = UInt32(d.object(forKey: other + "Code") as? Int ?? Int(UInt32.max))
        let otherMods = UInt32(d.object(forKey: other + "Modifiers") as? Int ?? 0)
        return controller.saveShortcuts(hold: kind == "hold" ? code : otherCode, holdMods: kind == "hold" ? mods : otherMods,
            toggle: kind == "toggle" ? code : otherCode, toggleMods: kind == "toggle" ? mods : otherMods, useFn: true)
    }
    private func reset(_ kind: String) { stop(); if save(kind, code: .max, mods: 0) { revision += 1; message = "Using Fn shortcuts." } }
}
