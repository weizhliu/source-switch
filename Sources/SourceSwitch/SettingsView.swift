import SwiftUI

struct SettingsView: View {
    @Bindable var state: AppState

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

            GroupBox {
                Toggle("Launch at login", isOn: $state.launchAtLogin)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            }
        }
        .padding(20)
        .frame(width: 600)
        .onAppear(perform: state.refreshSources)
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
                .help("Shown in the menu bar")

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
