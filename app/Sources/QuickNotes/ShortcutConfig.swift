import Foundation
import AppKit
import HotKey
import Carbon

// MARK: - Shortcut Item

struct ShortcutItem: Codable, Equatable {
    var key: String
    var modifiers: [String]

    /// Convert to HotKey's Key
    var hotKeyKey: Key? {
        return keyFromString(key)
    }

    /// Convert to NSEvent modifier flags
    var eventModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for mod in modifiers {
            switch mod {
            case "command": flags.insert(.command)
            case "option": flags.insert(.option)
            case "control": flags.insert(.control)
            case "shift": flags.insert(.shift)
            default: break
            }
        }
        return flags
    }

    /// Convert to HotKey's NSEventModifierFlags
    var hotKeyModifiers: NSEvent.ModifierFlags {
        return eventModifiers
    }

    /// Display string like "⌃⌥⌘N"
    var displayString: String {
        var s = ""
        if modifiers.contains("control") { s += "⌃" }
        if modifiers.contains("option") { s += "⌥" }
        if modifiers.contains("shift") { s += "⇧" }
        if modifiers.contains("command") { s += "⌘" }
        s += key.uppercased()
        return s
    }

    /// Check if an NSEvent matches this shortcut
    func matches(event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags == eventModifiers && event.charactersIgnoringModifiers?.lowercased() == key.lowercased()
    }

    private func keyFromString(_ s: String) -> Key? {
        switch s.lowercased() {
        case "a": return .a
        case "b": return .b
        case "c": return .c
        case "d": return .d
        case "e": return .e
        case "f": return .f
        case "g": return .g
        case "h": return .h
        case "i": return .i
        case "j": return .j
        case "k": return .k
        case "l": return .l
        case "m": return .m
        case "n": return .n
        case "o": return .o
        case "p": return .p
        case "q": return .q
        case "r": return .r
        case "s": return .s
        case "t": return .t
        case "u": return .u
        case "v": return .v
        case "w": return .w
        case "x": return .x
        case "y": return .y
        case "z": return .z
        case "0": return .zero
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "5": return .five
        case "6": return .six
        case "7": return .seven
        case "8": return .eight
        case "9": return .nine
        case "space": return .space
        case "`": return .grave
        case "-": return .minus
        case "=": return .equal
        case "[": return .leftBracket
        case "]": return .rightBracket
        case "\\": return .backslash
        case ";": return .semicolon
        case "'": return .quote
        case ",": return .comma
        case ".": return .period
        case "/": return .slash
        default: return nil
        }
    }
}

// MARK: - Shortcuts Config

struct ShortcutsData: Codable {
    var toggleNotes: ShortcutItem
    var newNote: ShortcutItem
    var deleteNote: ShortcutItem
    var hideNote: ShortcutItem
}

struct ConfigFile: Codable {
    var shortcuts: ShortcutsData
}

// MARK: - ShortcutConfig Manager

class ShortcutConfig: ObservableObject {
    static let shared = ShortcutConfig()

    @Published var shortcuts: ShortcutsData

    private let configDir: URL
    private let configFile: URL

    static let defaultShortcuts = ShortcutsData(
        toggleNotes: ShortcutItem(key: "n", modifiers: ["control", "option", "command"]),
        newNote: ShortcutItem(key: "n", modifiers: ["command"]),
        deleteNote: ShortcutItem(key: "d", modifiers: ["command"]),
        hideNote: ShortcutItem(key: "w", modifiers: ["command"])
    )

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".quick-notes")
        configFile = configDir.appendingPathComponent("config.json")
        shortcuts = ShortcutConfig.defaultShortcuts
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(ConfigFile.self, from: data) else {
            return
        }
        shortcuts = config.shortcuts
    }

    func save() {
        let config = ConfigFile(shortcuts: shortcuts)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(config) else { return }

        let fm = FileManager.default
        if !fm.fileExists(atPath: configDir.path) {
            try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        }
        try? data.write(to: configFile, options: .atomic)
    }

    /// Callback when shortcuts change (used to re-register global hotkey)
    var onShortcutsChanged: (() -> Void)?

    func update(_ keyPath: WritableKeyPath<ShortcutsData, ShortcutItem>, with item: ShortcutItem) {
        shortcuts[keyPath: keyPath] = item
        save()
        onShortcutsChanged?()
    }
}
