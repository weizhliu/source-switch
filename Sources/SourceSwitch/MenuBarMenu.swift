import SwiftUI

struct MenuBarMenu: View {
    let state: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ForEach(state.sources) { source in
            Toggle(isOn: Binding(
                get: { state.currentSourceID == source.id },
                set: { if $0 { state.select(source) } }
            )) {
                Text(source.menuBarGlyph + "  " + source.name)
                    + Text(state.shortcuts[source.id].map { "    \($0.description)" } ?? "")
            }
        }

        Divider()

        Button("Settings…", action: openSettingsInFront)
            .keyboardShortcut(",")

        Button("Quit SourceSwitch") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// An app without a Dock icon isn't raised on activation, so order the window front ourselves.
    private func openSettingsInFront() {
        openSettings()
        NSApp.activate()
        DispatchQueue.main.async {
            for window in NSApp.windows where window.canBecomeKey && !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}
