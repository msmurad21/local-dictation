import AppKit
import SwiftUI
import Combine
import DictationCore

final class RecordingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class OverlayController {
    private let panel: RecordingPanel
    private var subscriptions = Set<AnyCancellable>()
    private var edge = UserDefaults.standard.string(forKey: "overlayEdge") ?? "bottom"
    private var fraction = UserDefaults.standard.object(forKey: "overlayFraction") as? Double ?? 0.5
    private var screenID = UserDefaults.standard.object(forKey: "overlayScreen") as? UInt32
    private var dragging = false
    private var dragOrigin: NSPoint?
    private var mouseOrigin: NSPoint?

    init(controller: DictationController) {
        panel = RecordingPanel(contentRect: NSRect(x: 0, y: 0, width: 48, height: 30), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Dictation control"
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: FloatingControl(controller: controller, drag: { [weak self] ended in self?.drag(ended: ended) }, pin: { [weak self] edge in self?.pin(edge) }))
        controller.$recording.combineLatest(controller.$busy, controller.$starting).sink { [weak self] recording, busy, starting in
            guard let self else { return }
            self.panel.setContentSize(NSSize(width: recording || busy || starting ? 230 : 48, height: recording || busy || starting ? 54 : 30))
            if !self.dragging { self.position() }
        }.store(in: &subscriptions)
        controller.$showOverlay.sink { [weak self] visible in
            if visible { self?.position(); self?.panel.orderFrontRegardless() } else { self?.panel.orderOut(nil) }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification).sink { [weak self] _ in self?.position() }.store(in: &subscriptions)
        position()
        if controller.showOverlay { panel.orderFrontRegardless() }
    }
    private func screen() -> NSScreen? {
        NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == screenID } ?? NSScreen.main ?? NSScreen.screens.first
    }
    private func position() {
        guard let screen = screen() else { return }
        let area = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let size = panel.frame.size
        let x = area.minX + (area.width - size.width) * max(0, min(1, fraction))
        let y = area.minY + (area.height - size.height) * max(0, min(1, fraction))
        let origin: NSPoint
        switch edge {
        case "left": origin = NSPoint(x: area.minX, y: y)
        case "right": origin = NSPoint(x: area.maxX - size.width, y: y)
        case "top": origin = NSPoint(x: x, y: area.maxY - size.height)
        default: origin = NSPoint(x: x, y: area.minY)
        }
        panel.setFrameOrigin(origin)
    }
    private func pin(_ value: String) { edge = value; save(); position() }
    private func save() {
        UserDefaults.standard.set(edge, forKey: "overlayEdge")
        UserDefaults.standard.set(fraction, forKey: "overlayFraction")
        if let screenID { UserDefaults.standard.set(screenID, forKey: "overlayScreen") }
    }
    private func drag(ended: Bool) {
        if dragOrigin == nil { dragOrigin = panel.frame.origin; mouseOrigin = NSEvent.mouseLocation; dragging = true }
        if let origin = dragOrigin, let mouse = mouseOrigin {
            let now = NSEvent.mouseLocation
            panel.setFrameOrigin(NSPoint(x: origin.x + now.x - mouse.x, y: origin.y + now.y - mouse.y))
        }
        guard ended else { return }
        dragging = false; dragOrigin = nil; mouseOrigin = nil
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? self.screen()
        guard let screen else { return }
        screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
        let area = screen.visibleFrame
        let distances = [("left", abs(center.x - area.minX)), ("right", abs(center.x - area.maxX)), ("top", abs(center.y - area.maxY)), ("bottom", abs(center.y - area.minY))]
        edge = distances.min(by: { $0.1 < $1.1 })!.0
        fraction = edge == "left" || edge == "right" ? (center.y - area.minY) / area.height : (center.x - area.minX) / area.width
        save(); position()
    }
}

struct FloatingControl: View {
    @ObservedObject var controller: DictationController
    let drag: (Bool) -> Void
    let pin: (String) -> Void
    @State private var hovering = false
    var active: Bool { controller.recording || controller.busy || controller.starting }
    var body: some View {
        HStack(spacing: 8) {
            if active {
                Button { controller.cancel() } label: { Image(systemName: "xmark").frame(width: 24, height: 30) }.disabled(controller.submitting).help("Cancel recording (Escape)")
                if controller.recording {
                    HStack(spacing: 2) {
                        ForEach(Array(controller.levels.enumerated()), id: \.offset) { _, level in
                            Capsule().fill(Color.mint).frame(width: 2, height: max(3, CGFloat(level) * 22))
                        }
                    }.frame(width: 110, height: 28)
                        .overlay(alignment: .bottom) { Text(String(format: "%d:%02d", Int(controller.elapsed) / 60, Int(controller.elapsed) % 60)).font(.system(size: 8, design: .monospaced)).offset(y: 9).foregroundStyle(.white.opacity(0.6)) }
                } else { ProgressView().controlSize(.small).frame(width: 110, height: 28) }
                Button { controller.finish() } label: { Image(systemName: "checkmark").foregroundStyle(.mint).frame(width: 24, height: 30) }.disabled(!controller.recording).help("Finish and paste")
            } else {
                Button { controller.toggleRecording() } label: {
                    Capsule().fill(.white.opacity(hovering ? 0.85 : 0.55))
                        .frame(width: 18, height: 3)
                        .frame(width: 34, height: 14)
                        .contentShape(Capsule())
                }.disabled(!controller.ready)
                    .accessibilityLabel("Start hands-free dictation")
                    .help("Click to record. Drag to a screen edge. Right-click for the dashboard.")
            }
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .padding(.horizontal, active ? 12 : 0).padding(.vertical, active ? 5 : 0)
        .background(Color(red: 0.07, green: 0.09, blue: 0.13), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(active || hovering ? 0.16 : 0.06)))
        .shadow(color: .black.opacity(active ? 0.2 : 0.08), radius: 3, y: 1)
        .opacity(active || hovering ? 1 : 0.28)
        .animation(.easeInOut(duration: 0.25), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(Capsule())
        .simultaneousGesture(DragGesture(minimumDistance: 6).onChanged { _ in drag(false) }.onEnded { _ in drag(true) })
        .contextMenu {
            Button("Dashboard") { controller.showDashboard?() }
            Button(controller.mode == .pushToTalk ? "Switch to toggle mode" : "Switch to push to talk") { controller.mode = controller.mode == .pushToTalk ? .toggle : .pushToTalk }
            ForEach(["left", "right", "top", "bottom"], id: \.self) { edge in Button("Pin to \(edge)") { pin(edge) } }
        }
        .padding(7)
    }
}
