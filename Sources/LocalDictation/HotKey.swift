import Carbon
import AppKit
import DictationCore

@MainActor final class HotKey {
    private var reference: EventHotKeyRef?
    private var toggleReference: EventHotKeyRef?
    private var customRouter = ShortcutRouter()
    private var holdCode = UInt32(UserDefaults.standard.object(forKey: "holdCode") as? Int ?? Int(UInt32.max))
    private var holdModifiers = UInt32(UserDefaults.standard.object(forKey: "holdModifiers") as? Int ?? 6144)
    private var toggleCode = UInt32(UserDefaults.standard.object(forKey: "toggleCode") as? Int ?? Int(UInt32.max))
    private var toggleModifiers = UInt32(UserDefaults.standard.object(forKey: "toggleModifiers") as? Int ?? 6144)
    var fnEnabled = UserDefaults.standard.object(forKey: "fnEnabled") as? Bool ?? true
    private var handler: EventHandlerRef?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var fnDown = false
    private var consumedSpace = false
    private var router = ShortcutRouter()
    var mode: RecordingMode = .pushToTalk
    var canCancel = false
    var suspended = false
    var isHandsFree: (() -> Bool)?
    var onAction: ((ShortcutAction) -> Void)?
    var onCancel: (() -> Void)?
    var fnAvailable: Bool { tap != nil && fnEnabled }

    func register() throws {
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)), EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                let instance = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
                guard !instance.suspended else { return }
                var identity = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identity) == noErr else { return }
                let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                let action: ShortcutAction?
                if identity.id == 2 {
                    action = pressed ? (instance.isHandsFree?() == true ? .finish : .toggle) : nil
                } else {
                    action = pressed ? instance.customRouter.press(mode: .pushToTalk, finishingHandsFree: instance.isHandsFree?() ?? false) : instance.customRouter.release(mode: .pushToTalk)
                }
                if let action { instance.onAction?(action) }
            }
            return noErr
        }, 2, &types, pointer, &handler)
        guard installed == noErr else { throw AppError.message("Could not register the fallback shortcut.") }
        try installCustomKeys()
        refreshFn()
    }
    func setCapture(_ active: Bool) throws {
        guard active != suspended else { return }
        suspended = active; reset(); customRouter.reset()
        if active {
            if let reference { UnregisterEventHotKey(reference) }; reference = nil
            if let toggleReference { UnregisterEventHotKey(toggleReference) }; toggleReference = nil
        } else { try installCustomKeys() }
    }
    private func installCustomKeys() throws {
        guard !suspended else { return }
        if holdCode != UInt32.max {
        guard RegisterEventHotKey(holdCode, holdModifiers, EventHotKeyID(signature: 0x4C444943, id: 1), GetApplicationEventTarget(), 0, &reference) == noErr else {
            throw AppError.message("That push-to-talk shortcut is already in use. Choose another combination.")
        }
        }
        if toggleCode != UInt32.max {
        guard RegisterEventHotKey(toggleCode, toggleModifiers, EventHotKeyID(signature: 0x4C444943, id: 2), GetApplicationEventTarget(), 0, &toggleReference) == noErr else {
            if let reference { UnregisterEventHotKey(reference) }; reference = nil
            throw AppError.message("That hands-free shortcut is already in use. Choose another combination.")
        }
        }
    }
    func configure(hold: UInt32, holdMods: UInt32, toggle: UInt32, toggleMods: UInt32, useFn: Bool) throws {
        guard hold == UInt32.max || toggle == UInt32.max || hold != toggle || holdMods != toggleMods else { throw AppError.message("Choose different shortcuts for push-to-talk and hands-free.") }
        let old = (holdCode, holdModifiers, toggleCode, toggleModifiers)
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        if let toggleReference { UnregisterEventHotKey(toggleReference) }; toggleReference = nil
        holdCode = hold; holdModifiers = holdMods; toggleCode = toggle; toggleModifiers = toggleMods
        do { try installCustomKeys() }
        catch {
            holdCode = old.0; holdModifiers = old.1; toggleCode = old.2; toggleModifiers = old.3
            do { try installCustomKeys() } catch { throw AppError.message("Shortcut setup failed. Reopen the app to restore your saved shortcuts.") }
            throw error
        }
        fnEnabled = useFn
        refreshFn()
        reset(); customRouter.reset()
        for (key, value) in [("holdCode", hold), ("holdModifiers", holdMods), ("toggleCode", toggle), ("toggleModifiers", toggleMods)] { UserDefaults.standard.set(Int(value), forKey: key) }
        UserDefaults.standard.set(useFn, forKey: "fnEnabled")
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
        guard !suspended else { return false }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if fnEnabled && type == .flagsChanged && key == 63 {
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
        if let toggleReference { UnregisterEventHotKey(toggleReference) }; toggleReference = nil
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        if let handler { RemoveEventHandler(handler) }; handler = nil
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }; source = nil
        if let tap { CFMachPortInvalidate(tap) }; tap = nil
    }
}
