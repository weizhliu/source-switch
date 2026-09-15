import SwiftUI

struct MenuBarMenu: View {
    let state: AppState
    @Environment(\.openWindow) private var openWindow

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

        Button("Settings…") {
            openWindow(id: SettingsView.windowID)
        }
        .keyboardShortcut(",")

        Button("Quit SourceSwitch") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
