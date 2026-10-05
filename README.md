# SourceSwitch

Menu-bar app that switches macOS input sources (ABC / 注音 / あ …) with global
keyboard shortcuts — one shortcut per source, working in every app. No
dependencies.

## Build (no Xcode needed)

```sh
scripts/build-app.sh            # → build/SourceSwitch.app
scripts/build-app.sh --install  # → /Applications/SourceSwitch.app and launch
```

Requires the Command Line Tools with Swift 6.2+ and macOS 15+.

```sh
scripts/test.sh                 # unit tests (Swift Testing)
scripts/ime-probe.sh [rounds]   # end-to-end: does a switch reach the front app's IME?
scripts/ime-probe.sh --native   # same check for macOS's own ⌃Space / ⌃⌥Space
```

`ime-probe.sh` opens IMEProbe, a text view that stays frontmost while
`SourceSwitch --select <id>` switches from another process, as a hotkey does.
It types "ka" after each switch and reports which source actually handled it.
It takes focus and changes the input source for about a minute, so don't type
while it runs. It needs a keyboard layout and at least two input methods enabled.
`--native` presses the real shortcuts, so IMEProbe needs Accessibility
(System Settings › Privacy & Security › Accessibility); it asks on first run.

## Use

- The menu bar shows the current source (`Ａ`, `注`, `あ`). Click it to
  switch by mouse or open **Settings…**.
- In Settings, click a source's shortcut field, press your combo (e.g. ⌃⌥1).
  ✕ or ⌫ clears it, Esc cancels. Shortcuts are saved immediately and survive relaunch.

## Layout

```
Sources/SourceSwitch/
  App.swift            @main — MenuBarExtra + Settings scenes
  AppState.swift       @Observable state: sources, current, shortcuts, login item
  InputSource.swift    model + Text Input Source Services (Carbon) queries
  Shortcut.swift       key combo value: parse from NSEvent, "⌃⌥1" text, system-conflict check
  HotKeys.swift        global hotkeys via RegisterEventHotKey
  ShortcutField.swift  System Settings-style recorder field
  MenuBarMenu.swift    the dropdown
  SettingsView.swift   per-source row: label · name · shortcut field
Sources/IMEProbe/      front-app harness for scripts/ime-probe.sh
```

## Notes

- Sources are read from System Settings › Keyboard › Input Sources; add or
  remove them there and the app updates by itself.
- ⌃Space / ⌃⌥Space are macOS's own input-source shortcuts; the field refuses
  combos macOS has claimed. Either pick other keys or disable Apple's under
  System Settings › Keyboard › Keyboard Shortcuts › Input Sources.
- Hotkeys use Carbon's `RegisterEventHotKey`: still the only macOS API that is
  system-wide, needs no Accessibility permission, and swallows the keystroke.
  Modifier-only shortcuts (e.g. tapping Right ⌘ alone) are not supported.
- Switching does what macOS's own switcher (TextInputSwitcher) does: resolve
  the source by ID, `TISEnableInputSource`, then `TISSelectInputSource`.
  Without the enable step, a change made from another process often isn't
  applied by the front app's IME session even though every indicator says it was.
- The Command Line Tools ship no SwiftUI macro plugin, and on the macOS 27 SDK
  `@State` is a macro, so `scripts/build-app.sh` compiles against the 26.x SDK.
  With Xcode installed, drop the `--sdk` flag.
