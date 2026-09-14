import AppKit
import Carbon

/// A key combination in Carbon terms, which is what `RegisterEventHotKey` takes.
struct Shortcut: Codable, Hashable, CustomStringConvertible {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let modifierMask = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    static let functionKeyCodes = Set(
        [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
         kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
            .map(UInt32.init)
    )

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers & Self.modifierMask
    }

    /// Nil when the key-down isn't usable as a global hotkey.
    init?(keyDownEvent event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard Self.isUsableAsHotKey(keyCode: keyCode, carbonModifiers: modifiers) else { return nil }
        self.init(keyCode: keyCode, carbonModifiers: modifiers)
    }

    /// A function key on its own, or any key with ⌃, ⌥ or ⌘. (⇧ alone won't register.)
    static func isUsableAsHotKey(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        carbonModifiers & ~UInt32(shiftKey) != 0 || functionKeyCodes.contains(keyCode)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    /// "⌃⌥1", "⌘⇧Space", "F5" …
    var description: String { modifierSymbols + keyName }

    /// Combos macOS has claimed for itself (Spotlight, screenshots, ⌃Space …).
    var isReservedBySystem: Bool {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let entries = unmanaged?.takeRetainedValue() as? [[String: Any]]
        else { return false }
        return entries.contains { entry in
            entry[kHISymbolicHotKeyEnabled] as? Bool == true
                && (entry[kHISymbolicHotKeyCode] as? Int).map(UInt32.init) == keyCode
                && (entry[kHISymbolicHotKeyModifiers] as? Int).map { UInt32($0) & Self.modifierMask } == carbonModifiers
        }
    }

    // MARK: - Display

    private var modifierSymbols: String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols
    }

    private var keyName: String {
        Self.specialKeyNames[keyCode] ?? Self.layoutCharacter(forKeyCode: keyCode) ?? "Key \(keyCode)"
    }

    private static let specialKeyNames: [UInt32: String] = {
        var names: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
            kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘",
            kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_ANSI_KeypadEnter: "⌤",
        ]
        let functionKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
        for (index, code) in functionKeys.enumerated() { names[code] = "F\(index + 1)" }
        return Dictionary(uniqueKeysWithValues: names.map { (UInt32($0.key), $0.value) })
    }()

    /// The character the key produces on the current ASCII-capable layout.
    private static func layoutCharacter(forKeyCode keyCode: UInt32) -> String? {
        guard let layout = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let dataPointer = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(dataPointer).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { bytes in
            UCKeyTranslate(
                bytes.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self),
                UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, characters.count, &length, &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}
