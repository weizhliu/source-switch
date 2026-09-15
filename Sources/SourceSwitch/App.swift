import SwiftUI

@main
struct SourceSwitchApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var state = AppState()
    @AppStorage(Preferences.showsMenuBarIcon) private var showsMenuBarIcon = true

    var body: some Scene {
        MenuBarExtra(isInserted: $showsMenuBarIcon) {
            MenuBarMenu(state: state)
        } label: {
            Text("ss")
        }

        Window("SourceSwitch", id: SettingsView.windowID) {
            SettingsView(state: state)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .onChange(of: delegate.reopenRequests) {
            openWindow(id: SettingsView.windowID)
        }
    }
}

@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var reopenRequests = 0

    /// Closing the settings window must not quit the app; the hotkeys live in this process.
    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        false
    }

    /// Opening the app while it's already running (Spotlight, Finder, Dock) with no window
    /// showing should bring up the settings window — SwiftUI doesn't do that for a
    /// launch-suppressed `Window` on its own.
    func applicationShouldHandleReopen(_ application: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { reopenRequests += 1 }
        return true
    }
}

enum Preferences {
    static let showsMenuBarIcon = "showsMenuBarIcon"
}
