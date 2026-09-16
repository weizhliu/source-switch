import Testing
@testable import SourceSwitch

/// Switches the machine's input source for a moment and restores it.
struct InputSourceSwitchTests {
    @Test func selectingMakesTheSourceCurrent() throws {
        let original = try #require(InputSource.current())
        let target = try #require(InputSource.allEnabled().first { $0.id != original.id })
        defer { original.select() }

        #expect(target.select())
        #expect(InputSource.current()?.id == target.id)
    }

    @Test func selectingAnUnknownSourceFailsAndChangesNothing() throws {
        let original = try #require(InputSource.current())
        let unknown = InputSource(id: "com.example.not-installed", name: "Nope", language: nil)

        #expect(!unknown.select())
        #expect(InputSource.current()?.id == original.id)
    }

    @Test func restoringTheOriginalSourceSucceeds() throws {
        let original = try #require(InputSource.current())
        #expect(original.select())
        #expect(InputSource.current()?.id == original.id)
    }
}
