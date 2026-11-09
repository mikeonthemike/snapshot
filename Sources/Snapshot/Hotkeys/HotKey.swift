import Cocoa
import Carbon.HIToolbox

struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon modifier mask
    var key: String         // display label for the key

    var display: String {
        var m = ""
        if modifiers & UInt32(controlKey) != 0 { m += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { m += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { m += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { m += "⌘" }
        return m + key
    }

    /// Key equivalent for showing the shortcut beside a menu item (single-character keys only).
    var menuKey: String { key.count == 1 ? key.lowercased() : "" }

    var menuMask: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { f.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { f.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { f.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { f.insert(.command) }
        return f
    }

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        return m
    }

    static func label(for event: NSEvent) -> String {
        let special: [UInt16: String] = [
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
            109: "F10", 103: "F11", 111: "F12",
        ]
        return special[event.keyCode] ?? (event.charactersIgnoringModifiers ?? "?").uppercased()
    }
}

enum HotKeyAction: UInt32, CaseIterable {
    case capture = 1, fullScreen = 2, copyText = 3

    var defaultsKey: String { "hotkey.\(rawValue)" }
    var title: String {
        switch self {
        case .capture: return "Capture area"
        case .fullScreen: return "Capture full screen"
        case .copyText: return "Copy text from screen"
        }
    }
    var fallback: HotKey {
        switch self {
        case .capture: return HotKey(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey | shiftKey), key: "A")
        case .fullScreen: return HotKey(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(optionKey | shiftKey), key: "F")
        case .copyText: return HotKey(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(optionKey | shiftKey), key: "T")
        }
    }
}
