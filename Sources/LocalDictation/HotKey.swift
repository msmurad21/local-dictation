import Carbon
import AppKit
import DictationCore

@MainActor final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var fnDown = false
    private var consumedSpace = false
    private var router = ShortcutRouter()
    var mode: RecordingMode = .pushToTalk
    var canCancel = false
    var isHandsFree: (() -> Bool)?
    var onAction: ((ShortcutAction) -> Void)?
    var onCancel: (() -> Void)?
    var fnAvailable: Bool { tap != nil }

    func register() throws {
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)), EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                let instance = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
                let action = GetEventKind(event) == UInt32(kEventHotKeyPressed) ? instance.router.press(mode: instance.mode, finishingHandsFree: instance.isHandsFree?() ?? false) : instance.router.release(mode: instance.mode)
                if let action { instance.onAction?(action) }
            }
            return noErr
        }, 2, &types, pointer, &handler)
        guard installed == noErr else { throw AppError.message("Could not register the fallback shortcut.") }
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x4C444943, id: 1), GetApplicationEventTarget(), 0, &reference)
        guard status == noErr else { throw AppError.message("Control–Option–Space is in use by another app.") }
        refreshFn()
    }
    func refreshFn() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = [CGEventType.flagsChanged, .keyDown, .keyUp].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    owner.router.reset(); owner.fnDown = false; owner.onCancel?()
                    return Unmanaged.passUnretained(event)
                }
                return owner.handle(type, event) ? nil : Unmanaged.passUnretained(event)
            }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap {
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .flagsChanged && key == 63 {
            let down = event.flags.contains(.maskSecondaryFn)
            if down != fnDown {
                fnDown = down
                let action = down ? router.press(mode: mode, finishingHandsFree: isHandsFree?() ?? false) : router.release(mode: mode)
                if let action { onAction?(action) }
            }
            return true
        }
        if key == 49 && type == .keyDown && fnDown {
            consumedSpace = true
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0, let action = router.space() { onAction?(action) }
            return true
        }
        if key == 49 && type == .keyUp && consumedSpace { consumedSpace = false; return true }
        if key == 53 && type == .keyDown && canCancel { onCancel?(); return true }
        return false
    }
    func reset() { router.reset(); fnDown = false; consumedSpace = false }
    func invalidate() {
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        if let handler { RemoveEventHandler(handler) }; handler = nil
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }; source = nil
        if let tap { CFMachPortInvalidate(tap) }; tap = nil
    }
}
