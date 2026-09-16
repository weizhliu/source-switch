import Carbon

/// A keyboard input source the user can switch to: a layout (ABC) or an IME mode (Zhuyin, Hiragana).
struct InputSource: Identifiable, Hashable {
    /// `com.apple.keylayout.ABC`, `com.apple.inputmethod.TCIM.Zhuyin`, …
    let id: String
    /// Localized, e.g. "Zhuyin – Traditional".
    let name: String
    /// Primary BCP-47 tag, e.g. "zh-Hant".
    let language: String?

    init(id: String, name: String, language: String?) {
        self.id = id
        self.name = name
        self.language = language
    }

    /// One glyph per source (Ａ / 注 / あ …), all the same width so the menu bar item never resizes.
    var menuBarGlyph: String {
        switch language {
        case "zh-Hant":
            if id.contains("Zhuyin") { return "注" }
            if id.contains("Cangjie") { return "倉" }
            if id.contains("Sucheng") { return "速" }
            return "繁"
        case "zh-Hans": return "拼"
        case "ja": return id.hasSuffix("Katakana") ? "ア" : "あ"
        case "ko": return "한"
        default: return Self.fullWidthForm(of: name.prefix(1).uppercased())
        }
    }

    /// The same sequence as macOS's own switcher (TextInputSwitcher): resolve the source by
    /// ID, enable it even though it already is, then select it. Without the enable step other
    /// apps often keep their old IME session while every indicator shows the new source.
    @discardableResult
    func select() -> Bool {
        guard let ref = Self.sources(matching: [kTISPropertyInputSourceID: id]).first else { return false }
        TISEnableInputSource(ref)
        return TISSelectInputSource(ref) == noErr
    }

    /// Enabled sources in System Settings order. Parent IMEs aren't select-capable and
    /// palettes are another category, so both drop out.
    static func allEnabled() -> [InputSource] {
        sources(matching: [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
            kTISPropertyInputSourceIsSelectCapable: true,
            kTISPropertyInputSourceIsEnabled: true,
        ])
        .compactMap(InputSource.init)
    }

    static func current() -> InputSource? {
        TISCopyCurrentKeyboardInputSource().flatMap { InputSource($0.takeRetainedValue()) }
    }

    /// "A" → "Ａ": printable ASCII mapped onto the Fullwidth Forms block.
    static func fullWidthForm(of text: String) -> String {
        String(text.unicodeScalars.map { scalar in
            guard (0x21...0x7E).contains(scalar.value),
                  let wide = Unicode.Scalar(scalar.value + 0xFEE0) else { return Character(scalar) }
            return Character(wide)
        })
    }

    private static func sources(matching properties: [CFString: Any]) -> [TISInputSource] {
        TISCreateInputSourceList(properties as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] ?? []
    }

    private init?(_ ref: TISInputSource) {
        guard let id: String = ref[kTISPropertyInputSourceID] else { return nil }
        self.init(id: id, name: ref[kTISPropertyLocalizedName] ?? id,
                  language: (ref[kTISPropertyInputSourceLanguages] as [String]?)?.first)
    }
}

private extension TISInputSource {
    subscript<T>(property: CFString) -> T? {
        guard let pointer = TISGetInputSourceProperty(self, property) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
    }
}
