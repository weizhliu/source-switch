import Carbon
import Foundation
import Observation
import ServiceManagement

/// Single source of truth for the menu bar and Settings.
@Observable
final class AppState {
    private(set) var sources: [InputSource] = []
    private(set) var currentSourceID: String?

    /// Persisted; every change re-registers the global hotkeys.
    private(set) var shortcuts: [InputSource.ID: Shortcut] = AppState.loadSavedShortcuts() {
        didSet {
            saveShortcuts()
            registerHotKeys()
        }
    }

    var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                try launchAtLogin ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    var currentSource: InputSource? { sources.first { $0.id == currentSourceID } }

    init() {
        refreshSources()
        observeSystemInputSourceChanges()
    }

    func refreshSources() {
        sources = InputSource.allEnabled()
        currentSourceID = InputSource.current()?.id
        registerHotKeys()
    }

    func select(_ source: InputSource) {
        if source.select() { currentSourceID = source.id }
    }

    func assign(_ shortcut: Shortcut?, to source: InputSource) {
        shortcuts = Self.assigning(shortcut, to: source.id, in: shortcuts)
    }

    /// A combo belongs to one source only: assigning it takes it away from any other source.
    static func assigning(_ shortcut: Shortcut?, to id: InputSource.ID,
                          in shortcuts: [InputSource.ID: Shortcut]) -> [InputSource.ID: Shortcut] {
        var updated = shortcuts.filter { $0.value != shortcut }
        updated[id] = shortcut
        return updated
    }

    /// While a shortcut is being recorded, pressing an existing combo must not switch sources.
    func suspendHotKeys() {
        HotKeys.shared.unregisterAll()
    }

    func resumeHotKeys() {
        registerHotKeys()
    }

    private func registerHotKeys() {
        HotKeys.shared.unregisterAll()
        for source in sources {
            guard let shortcut = shortcuts[source.id] else { continue }
            HotKeys.shared.register(shortcut) { [weak self] in self?.select(source) }
        }
    }

    private func observeSystemInputSourceChanges() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: .init(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.currentSourceID = InputSource.current()?.id }
        }
        center.addObserver(forName: .init(kTISNotifyEnabledKeyboardInputSourcesChanged as String), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.refreshSources() }
        }
    }

    private static let shortcutsDefaultsKey = "shortcuts"

    private func saveShortcuts() {
        UserDefaults.standard.set(try? JSONEncoder().encode(shortcuts), forKey: Self.shortcutsDefaultsKey)
    }

    private static func loadSavedShortcuts() -> [InputSource.ID: Shortcut] {
        guard let data = UserDefaults.standard.data(forKey: shortcutsDefaultsKey) else { return [:] }
        return (try? JSONDecoder().decode([InputSource.ID: Shortcut].self, from: data)) ?? [:]
    }
}
