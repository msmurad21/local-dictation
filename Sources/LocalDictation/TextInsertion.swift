import AppKit
import ApplicationServices
import DictationCore

struct DestinationChanged: Error {}

struct InsertionTarget {
    let processID: pid_t
    let element: AXUIElement?
    let window: AXUIElement?
    let appName: String
    let context: DictationContext
    let bundleID: String

    static func attribute(_ object: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(object, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    static func capture() -> Self? {
        // Resolve the app owning the focused accessibility field without reading its value.
        let system = AXUIElementCreateSystemWide()
        let focusedApp = attribute(system, kAXFocusedApplicationAttribute)
        let field = focusedApp.flatMap { attribute($0, kAXFocusedUIElementAttribute) }
        var pid: pid_t = 0
        if let field { AXUIElementGetPid(field, &pid) }
        if pid == 0, let focusedApp { AXUIElementGetPid(focusedApp, &pid) }
        let app = pid > 0 ? NSRunningApplication(processIdentifier: pid) : NSWorkspace.shared.frontmostApplication
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        return Self(processID: app.processIdentifier,
                    element: field ?? attribute(ax, kAXFocusedUIElementAttribute),
                    window: attribute(ax, kAXFocusedWindowAttribute), appName: app.localizedName ?? "app",
                    context: .classify(bundleID: app.bundleIdentifier), bundleID: app.bundleIdentifier ?? "")
    }

    @MainActor func insert(_ text: String, onPaste: (() -> Void)? = nil) async throws -> String {
        guard AXIsProcessTrusted() else { throw AppError.message("Enable Accessibility for Local Dictation in System Settings. Your transcript is ready to copy.") }
        try validateFocus()
        if let element {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &role)
            if (role as? String) == "AXSecureTextField" { throw AppError.message("Dictation is not inserted into password fields.") }
        }
        // Some apps expose stale/proxy AX fields or reject AXSelectedText writes.
        // A paste is their native, compatible insertion path, even without an AX field.
        let board = NSPasteboard.general
        let saved = (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
            throw AppError.message("Could not send paste. Use Copy.")
        }
        // Wait until physical shortcut modifiers have been released.
        for _ in 0..<30 {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift, .maskSecondaryFn]).isEmpty { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let flags = CGEventSource.flagsState(.combinedSessionState)
        guard flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift, .maskSecondaryFn]).isEmpty else {
            throw AppError.message("Release the modifier keys before pasting. Your transcript is ready to copy.")
        }
        try validateFocus()
        board.clearContents()
        guard board.setString(text, forType: .string) else { board.writeObjects(saved); throw AppError.message("The clipboard is unavailable.") }
        let version = board.changeCount
        down.flags = .maskCommand; up.flags = .maskCommand
        down.postToPid(processID); up.postToPid(processID)
        onPaste?()
        try? await Task.sleep(for: .milliseconds(900))
        if board.changeCount == version { board.clearContents(); board.writeObjects(saved) }
        return "Paste sent to \(appName)"
    }
    @MainActor private func validateFocus() throws {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else {
            throw DestinationChanged()
        }
        let ax = AXUIElementCreateApplication(processID)
        if let window, let current = Self.attribute(ax, kAXFocusedWindowAttribute), !CFEqual(window, current) {
            throw DestinationChanged()
        }
        if let element, let current = Self.attribute(ax, kAXFocusedUIElementAttribute), !CFEqual(element, current) {
            // Only reject a proven move between editable fields; container proxies vary.
            var oldSettable: DarwinBoolean = false, newSettable: DarwinBoolean = false
            AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &oldSettable)
            AXUIElementIsAttributeSettable(current, kAXSelectedTextAttribute as CFString, &newSettable)
            if oldSettable.boolValue && newSettable.boolValue { throw DestinationChanged() }
        }
    }
}
