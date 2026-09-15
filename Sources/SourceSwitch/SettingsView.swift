import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    @Bindable var state: AppState
    @AppStorage(Preferences.showsMenuBarIcon) private var showsMenuBarIcon = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Input sources") {
                VStack(spacing: 0) {
                    ForEach(state.sources) { source in
                        SourceRow(source: source, state: state)
                        if source.id != state.sources.last?.id { Divider() }
                    }
                }
            }

            Text("Shortcuts work in every app. ⌃Space and ⌃⌥Space belong to macOS — pick something else, e.g. ⌃⌥1.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show in menu bar", isOn: $showsMenuBarIcon)
                    Toggle("Launch at login", isOn: $state.launchAtLogin)
                    if !showsMenuBarIcon {
                        Text("With the icon hidden, open SourceSwitch again to come back here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack {
                Text("Closing this window keeps the shortcuts active.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit SourceSwitch") { NSApp.terminate(nil) }
            }
        }
        .padding(20)
        .frame(width: 600)
        .onAppear {
            state.refreshSources()
            AppPresence.showInDock()
        }
        .onDisappear(perform: AppPresence.hideFromDock)
    }
}

/// While the window is open the app behaves like a normal one (Dock icon, app menu, ⌘-Tab);
/// once it's closed the app goes back to living only in the menu bar.
private enum AppPresence {
    static func showInDock() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    static func hideFromDock() {
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct SourceRow: View {
    let source: InputSource
    let state: AppState

    var body: some View {
        HStack(spacing: 12) {
            Text(source.menuBarGlyph)
                .font(.headline)
                .frame(width: 44, height: 28)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                Text(source.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            ShortcutField(source: source, state: state)
                .frame(width: 160)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
