import AppKit
import SwiftUI
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var panelManager = PanelManager.shared
    private var storage = NoteStorage.shared
    private var config = ShortcutConfig.shared
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Quick Notes")
            button.action = #selector(statusBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Register global hotkey from config
        registerGlobalHotKey()

        // Re-register when shortcuts change
        config.onShortcutsChanged = { [weak self] in
            self?.registerGlobalHotKey()
        }

        // Restore notes from last session
        panelManager.restoreAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelManager.saveAll()
        storage.flush()
    }

    // MARK: - Global HotKey

    private func registerGlobalHotKey() {
        hotKey = nil // unregister old one
        let shortcut = config.shortcuts.toggleNotes
        if let key = shortcut.hotKeyKey {
            hotKey = HotKey(key: key, modifiers: shortcut.hotKeyModifiers)
            hotKey?.keyDownHandler = { [weak self] in
                self?.toggleNotes()
            }
        }
    }

    // MARK: - Status Bar

    @objc func statusBarClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleNotes()
        }
    }

    @objc func toggleNotes() {
        if panelManager.hasVisiblePanels {
            panelManager.hideAll()
        } else if storage.notes.isEmpty {
            panelManager.createNewNote()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            panelManager.showAll()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let toggleShortcut = config.shortcuts.toggleNotes.displayString
        menu.addItem(NSMenuItem(title: "New Note", action: #selector(createNewNote), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toggle Notes (\(toggleShortcut))", action: #selector(toggleNotes), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func createNewNote() {
        panelManager.createNewNote()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PreferencesView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick Notes Preferences"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = window
    }

    @objc func quit() {
        panelManager.saveAll()
        storage.flush()
        NSApp.terminate(nil)
    }
}
