import AppKit
import Carbon
import Foundation
import Testing
@testable import SourceSwitch

struct ShortcutTests {
    @Test func describesModifiersInAppleOrderThenKey() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_1),
                                carbonModifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey))
        #expect(shortcut.description == "⌃⌥⇧⌘1")
    }

    @Test func describesLettersUppercased() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_K), carbonModifiers: UInt32(controlKey | optionKey))
        #expect(shortcut.description == "⌃⌥K")
    }

    @Test(arguments: [
        (kVK_Space, UInt32(cmdKey), "⌘Space"),
        (kVK_F5, UInt32(0), "F5"),
        (kVK_LeftArrow, UInt32(controlKey), "⌃←"),
        (kVK_Return, UInt32(optionKey), "⌥↩"),
    ])
    func namesSpecialKeys(keyCode: Int, modifiers: UInt32, expected: String) {
        #expect(Shortcut(keyCode: UInt32(keyCode), carbonModifiers: modifiers).description == expected)
    }

    @Test func ignoresModifierBitsOutsideTheMask() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_1), carbonModifiers: UInt32(controlKey) | 0xFF00_0000)
        #expect(shortcut.carbonModifiers == UInt32(controlKey))
    }

    @Test func requiresControlOptionOrCommandUnlessFunctionKey() {
        #expect(Shortcut.isUsableAsHotKey(keyCode: UInt32(kVK_ANSI_1), carbonModifiers: UInt32(controlKey)))
        #expect(Shortcut.isUsableAsHotKey(keyCode: UInt32(kVK_F5), carbonModifiers: 0))
        #expect(!Shortcut.isUsableAsHotKey(keyCode: UInt32(kVK_ANSI_1), carbonModifiers: 0))
        #expect(!Shortcut.isUsableAsHotKey(keyCode: UInt32(kVK_ANSI_1), carbonModifiers: UInt32(shiftKey)))
    }

    @Test func buildsFromKeyDownEvent() throws {
        let event = try #require(keyDown(keyCode: kVK_ANSI_2, modifiers: [.control, .option]))
        let shortcut = try #require(Shortcut(keyDownEvent: event))
        #expect(shortcut.keyCode == UInt32(kVK_ANSI_2))
        #expect(shortcut.carbonModifiers == UInt32(controlKey | optionKey))
    }

    @Test func rejectsUnmodifiedKeyDownEvent() throws {
        let event = try #require(keyDown(keyCode: kVK_ANSI_2, modifiers: []))
        #expect(Shortcut(keyDownEvent: event) == nil)
    }

    @Test func mapsEventFlagsToCarbonModifiers() {
        let modifiers = Shortcut.carbonModifiers(from: [.command, .shift, .capsLock])
        #expect(modifiers == UInt32(cmdKey | shiftKey))
    }

    @Test func roundTripsThroughJSON() throws {
        let original = Shortcut(keyCode: UInt32(kVK_ANSI_3), carbonModifiers: UInt32(cmdKey | optionKey))
        let decoded = try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func obscureComboIsNotReservedBySystem() {
        let shortcut = Shortcut(keyCode: UInt32(kVK_F19), carbonModifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey))
        #expect(!shortcut.isReservedBySystem)
    }

    private func keyDown(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> NSEvent? {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                         windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                         isARepeat: false, keyCode: UInt16(keyCode))
    }
}
