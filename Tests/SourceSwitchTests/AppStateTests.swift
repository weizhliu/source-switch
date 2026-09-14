import Carbon
import Testing
@testable import SourceSwitch

struct AppStateTests {
    private let combo = Shortcut(keyCode: UInt32(kVK_ANSI_1), carbonModifiers: UInt32(controlKey | optionKey))
    private let otherCombo = Shortcut(keyCode: UInt32(kVK_ANSI_2), carbonModifiers: UInt32(controlKey | optionKey))

    @Test func assigningAddsTheShortcut() {
        let result = AppState.assigning(combo, to: "abc", in: [:])
        #expect(result == ["abc": combo])
    }

    @Test func assigningNilRemovesTheShortcut() {
        let result = AppState.assigning(nil, to: "abc", in: ["abc": combo, "zhuyin": otherCombo])
        #expect(result == ["zhuyin": otherCombo])
    }

    @Test func assigningMovesAComboAwayFromItsPreviousOwner() {
        let result = AppState.assigning(combo, to: "zhuyin", in: ["abc": combo])
        #expect(result == ["zhuyin": combo])
    }

    @Test func assigningLeavesUnrelatedShortcutsAlone() {
        let result = AppState.assigning(combo, to: "abc", in: ["zhuyin": otherCombo])
        #expect(result == ["abc": combo, "zhuyin": otherCombo])
    }
}
