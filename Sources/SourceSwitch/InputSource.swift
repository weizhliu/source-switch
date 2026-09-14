import Carbon

/// A keyboard input source the user can switch to: a layout (ABC) or an IME mode (Zhuyin, Hiragana).
struct InputSource: Identifiable {
    /// `com.apple.keylayout.ABC`, `com.apple.inputmethod.TCIM.Zhuyin`, …
    let id: String
    /// Localized, e.g. "Zhuyin – Traditional".
    let name: String
    /// Primary BCP-47 tag, e.g. "zh-Hant".
    let language: String?
    /// The owning IME (`com.apple.inputmethod.TCIM`); nil for plain keyboard layouts.
    let imeBundleID: String?
    private let ref: TISInputSource

    var isKeyboardLayout: Bool { imeBundleID == nil }

    var menuBarGlyph: String { Self.menuBarGlyph(id: id, name: name, language: language) }

    /// One glyph per source (Ａ / 注 / あ …), all the same width so the menu bar item never resizes.
    static func menuBarGlyph(id: String, name: String, language: String?) -> String {
        switch language {
        case "zh-Hant":
            if id.contains("Zhuyin") { return "注" }
            if id.contains("Cangjie") { return "倉" }
            if id.contains("Sucheng") { return "速" }
            return "繁"
        case "zh-Hans": return "拼"
        case "ja": return id.hasSuffix("Katakana") ? "ア" : "あ"
        case "ko": return "한"
        default: return fullWidthForm(of: name.prefix(1).uppercased())
        }
    }

    /// "A" → "Ａ": printable ASCII mapped onto the Fullwidth Forms block.
    static func fullWidthForm(of text: String) -> String {
        String(text.unicodeScalars.map { scalar in
            guard (0x21...0x7E).contains(scalar.value),
                  let wide = Unicode.Scalar(scalar.value + 0xFEE0) else { return Character(scalar) }
            return Character(wide)
        })
    }

    @discardableResult
    func select() -> Bool {
        TISSelectInputSource(ref) == noErr
    }

    /// Enabled sources in System Settings order. Parent IMEs aren't select-capable
    /// and palettes are another category, so both drop out.
    static func allEnabled() -> [InputSource] {
        let all = TISCreateInputSourceList(nil, false).takeRetainedValue() as? [TISInputSource] ?? []
        return all
            .filter {
                $0[kTISPropertyInputSourceCategory] == kTISCategoryKeyboardInputSource as String
                    && $0[kTISPropertyInputSourceIsSelectCapable] == true
                    && $0[kTISPropertyInputSourceIsEnabled] == true
            }
            .compactMap(InputSource.init)
    }

    static func current() -> InputSource? {
        TISCopyCurrentKeyboardInputSource().flatMap { InputSource($0.takeRetainedValue()) }
    }

    private init?(_ ref: TISInputSource) {
        guard let id: String = ref[kTISPropertyInputSourceID] else { return nil }
        self.id = id
        self.name = ref[kTISPropertyLocalizedName] ?? id
        self.language = (ref[kTISPropertyInputSourceLanguages] as [String]?)?.first
        self.imeBundleID = ref[kTISPropertyBundleID]
        self.ref = ref
    }
}

private extension TISInputSource {
    subscript<T>(property: CFString) -> T? {
        guard let pointer = TISGetInputSourceProperty(self, property) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
    }
}
