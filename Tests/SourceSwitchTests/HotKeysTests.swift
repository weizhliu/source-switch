import Carbon
import Testing
@testable import SourceSwitch

struct HotKeysTests {
    private let combo = Shortcut(keyCode: UInt32(kVK_F19), carbonModifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey))

    @Test func registersAndUnregistersWithTheSystem() {
        defer { HotKeys.shared.unregisterAll() }
        #expect(HotKeys.shared.register(combo) {})
        HotKeys.shared.unregisterAll()
        #expect(HotKeys.shared.register(combo) {})
    }
}
