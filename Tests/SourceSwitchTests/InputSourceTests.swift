import Testing
@testable import SourceSwitch

struct InputSourceTests {
    @Test(arguments: [
        ("com.apple.keylayout.ABC", "ABC", "en", "Ａ"),
        ("com.apple.keylayout.US", "U.S.", "en", "Ｕ"),
        ("com.apple.inputmethod.TCIM.Zhuyin", "Zhuyin – Traditional", "zh-Hant", "注"),
        ("com.apple.inputmethod.TCIM.Cangjie", "Cangjie", "zh-Hant", "倉"),
        ("com.apple.inputmethod.SCIM.ITABC", "Pinyin – Simplified", "zh-Hans", "拼"),
        ("com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese", "Hiragana", "ja", "あ"),
        ("com.apple.inputmethod.Kotoeri.RomajiTyping.Katakana", "Katakana", "ja", "ア"),
        ("com.apple.inputmethod.Korean.2SetKorean", "2-Set Korean", "ko", "한"),
        ("com.apple.keylayout.French", "French", "fr", "Ｆ"),
    ])
    func menuBarGlyphIsOneFullWidthCharacter(id: String, name: String, language: String, expected: String) {
        #expect(InputSource(id: id, name: name, language: language).menuBarGlyph == expected)
    }

    @Test func fullWidthFormCoversPrintableASCIIOnly() {
        #expect(InputSource.fullWidthForm(of: "AZ09") == "ＡＺ０９")
        #expect(InputSource.fullWidthForm(of: "注 ") == "注 ")
    }

    @Test func enabledSourcesAreSelectableKeyboardSources() {
        let sources = InputSource.allEnabled()
        #expect(!sources.isEmpty)
        #expect(sources.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty })
        #expect(!sources.contains { $0.id.contains("CharacterPalette") })
    }

    @Test func currentSourceIsOneOfTheEnabledOnes() throws {
        let current = try #require(InputSource.current())
        #expect(InputSource.allEnabled().contains { $0.id == current.id })
    }
}
