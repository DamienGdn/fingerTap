import AppKit
import Carbon
import FingerTapCore

enum Keyboard {
    /// Posts the shortcut as if typed. Needs the Accessibility permission.
    static func send(_ shortcut: KeyShortcut) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else { return }
        var flags: CGEventFlags = []
        if shortcut.modifiers.contains(.control) { flags.insert(.maskControl) }
        if shortcut.modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if shortcut.modifiers.contains(.shift) { flags.insert(.maskShift) }
        if shortcut.modifiers.contains(.command) { flags.insert(.maskCommand) }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Physical key that types `character` with the current layout (W is not at the same place
    /// in QWERTY and AZERTY). Must run on the main thread.
    static func keyCode(typing character: Character) -> UInt16? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        let target = String(character).lowercased()
        return data.withUnsafeBytes { buffer -> UInt16? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for code in UInt16(0)..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                            OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count,
                                            &length, &characters)
                if status == noErr, String(utf16CodeUnits: characters, count: length).lowercased() == target {
                    return code
                }
            }
            return nil
        }
    }
}

extension KeyShortcut {
    /// The shortcut typed in a key-down event, or nil for a lone modifier.
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        var modifiers: Modifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        let special: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑",
            115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        ]
        let label = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard !label.isEmpty else { return nil }
        self.init(keyCode: event.keyCode, modifiers: modifiers, key: label)
    }
}
