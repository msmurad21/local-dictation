import AppKit
import SwiftUI
import DictationCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: DictationController!
    private var overlay: OverlayController!
    private var dashboard: NSWindow?
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let appRoot = NSMenuItem(); appRoot.submenu = appMenu; mainMenu.addItem(appRoot)
        let show = NSMenuItem(title: "Dashboard", action: #selector(openDashboard), keyEquivalent: "1")
        show.target = self; appMenu.addItem(show)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Local Dictation", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: "Edit")
        let editRoot = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); editRoot.submenu = edit; mainMenu.addItem(editRoot)
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        NSApp.mainMenu = mainMenu
        controller = DictationController()
        controller.updates.safeToRestart = { [weak self] in
            guard let c = self?.controller else { return false }
            return UpdatePolicy.mayRestart(recording: c.recording, starting: c.starting, busy: c.busy,
                submitting: c.submitting, hasUnpastedText: c.hasUnpastedText, dashboardActive: NSApp.isActive)
        }
        controller.updates.start()
        let check = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        check.target = self; appMenu.insertItem(check, at: 1)
        controller.showDashboard = { [weak self] in self?.openDashboard() }
        overlay = OverlayController(controller: controller)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Local Dictation")
        let menu = NSMenu()
        for (title, action) in [("Dashboard", #selector(openDashboard)), ("Start / finish dictation", #selector(toggle)), ("Show / hide floating control", #selector(toggleOverlay)), ("Check for Updates…", #selector(checkForUpdates)), ("Quit Local Dictation", #selector(quit))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu
        let resumed = UserDefaults.standard.bool(forKey: "resumeAfterUpdate")
        UserDefaults.standard.removeObject(forKey: "resumeAfterUpdate")
        if !resumed { openDashboard() }
    }
    @objc func openDashboard() {
        if dashboard == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Local Dictation"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 850, height: 680)
            window.contentView = NSHostingView(rootView: DashboardView(controller: controller, store: controller.store))
            window.center(); dashboard = window
        }
        NSApp.unhide(nil); NSApp.activate(ignoringOtherApps: true); dashboard?.makeKeyAndOrderFront(nil)
    }
    @objc func checkForUpdates() {
        if controller.updates.configured { controller.updates.checkForUpdates() }
        else {
            let alert = NSAlert(); alert.messageText = "Release channel not configured"
            alert.informativeText = "This development build has no signed update feed yet."
            alert.runModal()
        }
    }
    @objc func toggle() { if controller.recording { controller.finish() } else { controller.toggleRecording() } }
    @objc func toggleOverlay() { controller.showOverlay.toggle() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openDashboard(); return true }
    func applicationWillTerminate(_ notification: Notification) { controller.shutdown() }
}
