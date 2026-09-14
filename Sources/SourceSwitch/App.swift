import SwiftUI

@main
struct SourceSwitchApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(state: state)
        } label: {
            if let source = state.currentSource {
                Text(source.menuBarGlyph)
            } else {
                Image(systemName: "keyboard")
            }
        }

        Settings {
            SettingsView(state: state)
        }
    }
}
