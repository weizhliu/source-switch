import Carbon

/// System-wide hotkeys via Carbon's `RegisterEventHotKey`: still the only macOS API that
/// fires in every app, needs no Accessibility permission, and swallows the keystroke.
final class HotKeys {
    static let shared = HotKeys()

    private var actionsByID: [UInt32: () -> Void] = [:]
    private var registrations: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1

    private init() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in HotKeys.dispatch(event) }, 1, &pressed, nil, nil)
    }

    @discardableResult
    func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        let id = nextID
        nextID += 1
        var registration: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 0x5357_5443 /* 'SWTC' */, id: id)
        guard RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
                                  GetEventDispatcherTarget(), 0, &registration) == noErr,
              let registration
        else { return false }
        registrations.append(registration)
        actionsByID[id] = action
        return true
    }

    func unregisterAll() {
        registrations.forEach { UnregisterEventHotKey($0) }
        registrations = []
        actionsByID = [:]
    }

    private nonisolated static func dispatch(_ event: EventRef?) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                          nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        // Carbon delivers hotkey events on the main thread.
        MainActor.assumeIsolated { shared.actionsByID[hotKeyID.id]?() }
        return noErr
    }
}
