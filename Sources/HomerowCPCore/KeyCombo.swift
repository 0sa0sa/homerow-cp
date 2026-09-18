public struct KeyCombo: Equatable {
    public let keyCode: UInt32
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum KeyComboParser {
    // Carbon modifier flag values (cmdKey=0x100, shiftKey=0x200, optionKey=0x800, controlKey=0x1000)
    private static let modifierNames: [String: UInt32] = [
        "cmd": 0x100, "shift": 0x200, "option": 0x800, "alt": 0x800, "control": 0x1000, "ctrl": 0x1000,
    ]

    // macOS virtual keycodes for the subset of keys this app's default bindings use
    private static let keyCodeNames: [String: UInt32] = [
        "space": 49, "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "j": 38, "k": 40, "l": 37, "slash": 44,
    ]

    public static func parse(_ string: String) -> KeyCombo? {
        let parts = string.lowercased().split(separator: "+").map(String.init)
        guard let keyPart = parts.last, let keyCode = keyCodeNames[keyPart] else { return nil }

        var modifiers: UInt32 = 0
        for part in parts.dropLast() {
            guard let flag = modifierNames[part] else { return nil }
            modifiers |= flag
        }
        return KeyCombo(keyCode: keyCode, modifiers: modifiers)
    }
}
