import AppKit
import Carbon

// IMEProbe <SourceSwitch binary | --native> [rounds]
//
// Keeps a text view frontmost, switches sources from another process, types "ka" and checks
// which source actually handled it. Every indicator follows the switch; only typing shows
// whether the front app's IME session did. The switch comes from SourceSwitch (as its hotkey
// does) or, with --native, from macOS's own ⌃Space / ⌃⌥Space, for comparison.

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("usage: IMEProbe <SourceSwitch binary | --native> [rounds]")
    exit(2)
}
let isNative = arguments[1] == "--native"
let switcher = URL(fileURLWithPath: arguments[1])
let rounds = arguments.count > 2 ? Int(arguments[2]) ?? 3 : 3

struct Step {
    let from: String
    let to: String
    var typed = ""
}

final class Probe: NSObject, NSApplicationDelegate {
    private let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 420, height: 120),
                                  styleMask: [.titled], backing: .buffered, defer: false)
    private let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 120))

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.title = "IMEProbe — don't touch the keyboard or mouse"
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        // Launched from a terminal, cooperative activate() leaves the terminal in front.
        NSApp.activate(ignoringOtherApps: true)
        Task { exit(await run()) }
    }

    private func run() async -> Int32 {
        let sources = Sources.enabled()
        guard let original = Sources.current(), sources.count >= 3 else {
            print("Need at least three enabled input sources (e.g. ABC plus two input methods).")
            return 2
        }
        if isNative, !CGPreflightPostEventAccess() {
            CGRequestPostEventAccess()
            print("--native presses ⌃Space itself, which needs Accessibility: System Settings › "
                + "Privacy & Security › Accessibility › turn on IMEProbe, then run again.")
            return 4
        }
        for _ in 0..<20 where !(NSApp.isActive && window.isKeyWindow) {
            try? await Task.sleep(for: .milliseconds(100))
        }

        // Switch cross-process first: the bug depends on which IMEs this process has already
        // talked to, so calibrating in-process up front would hide it.
        var steps: [Step] = []
        if isNative {
            // ⌃⌥Space cycles through every source, so a layout can be followed by an IME other
            // than the last one used; ⌃Space only toggles back to the previous source.
            let presses = Array(repeating: NativeHotKey.next, count: sources.count * 2) + [.previous, .previous]
            for _ in 0..<rounds {
                for hotKey in presses {
                    guard let from = Sources.current() else { return 2 }
                    hotKey.press()
                    for _ in 0..<20 where Sources.current() == from {
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    guard let to = Sources.current(), to != from else {
                        print("\(hotKey) didn't change the input source. Is it enabled in System Settings › Keyboard › Keyboard Shortcuts › Input Sources?")
                        return 2
                    }
                    var step = Step(from: from, to: to)
                    guard let typed = await typeProbe() else { return 3 }
                    step.typed = typed
                    steps.append(step)
                }
            }
        } else {
            for _ in 0..<rounds {
                for target in sources.flatMap({ a in sources.filter { $0 != a }.flatMap { [a, $0] } }) {
                    guard let from = Sources.current(), from != target else { continue }
                    guard switchFromAnotherProcess(to: target) else {
                        print("SourceSwitch --select \(target) failed")
                        return 2
                    }
                    var step = Step(from: from, to: target)
                    guard let typed = await typeProbe() else { return 3 }
                    step.typed = typed
                    steps.append(step)
                }
            }
        }

        var fingerprints: [String: String] = [:]
        for source in sources {
            Sources.select(source)
            guard let typed = await typeProbe() else { return 3 }
            fingerprints[typed] = source
        }
        Sources.select(original)
        guard fingerprints.count == sources.count else {
            print("Two sources type \"ka\" identically, so they can't be told apart: \(fingerprints)")
            return 2
        }

        var failures = 0
        for step in steps {
            let actual = fingerprints[step.typed] ?? "unknown"
            let ok = actual == step.to
            if !ok { failures += 1 }
            print("\(ok ? "ok  " : "FAIL") \(Sources.short(step.from)) → \(Sources.short(step.to))"
                + (ok ? "" : "   typed with \(Sources.short(actual)) (\"\(step.typed)\")"))
        }
        print("\(failures) of \(steps.count) \(isNative ? "native" : "SourceSwitch") switches didn't reach the front app")
        return failures == 0 ? 0 : 1
    }

    private func switchFromAnotherProcess(to id: String) -> Bool {
        let process = Process()
        process.executableURL = switcher
        process.arguments = ["--select", id]
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// Returns what "ka" turned into, or nil if this window lost focus (the result would be meaningless).
    private func typeProbe() async -> String? {
        try? await Task.sleep(for: .milliseconds(300))
        guard NSApp.isActive, window.isKeyWindow else {
            print("IMEProbe lost focus; rerun without touching the keyboard or mouse.")
            return nil
        }
        // Posting key events to a process needs Accessibility, and AppKit-synthesized NSEvents
        // bypass the IME; NSEvents wrapping CGEvents go through it like real typing.
        for keyCode in [CGKeyCode(kVK_ANSI_K), CGKeyCode(kVK_ANSI_A)] {
            for isDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown)
                    .flatMap(NSEvent.init(cgEvent:)) else { continue }
                isDown ? textView.keyDown(with: event) : textView.keyUp(with: event)
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        try? await Task.sleep(for: .milliseconds(200))
        let typed = textView.string
        textView.inputContext?.discardMarkedText()
        textView.string = ""
        return typed
    }
}

/// macOS's own "Select the previous / next source in Input menu" shortcuts, pressed for real so
/// TextInputSwitcher handles them exactly as it does for the user.
enum NativeHotKey: CustomStringConvertible {
    case previous, next

    var description: String { self == .previous ? "⌃Space" : "⌃⌥Space" }

    /// Presses and releases the modifiers too: TextInputSwitcher commits the switch when they come up.
    func press() {
        let modifiers: [(CGKeyCode, CGEventFlags)] = self == .previous
            ? [(CGKeyCode(kVK_Control), .maskControl)]
            : [(CGKeyCode(kVK_Control), .maskControl), (CGKeyCode(kVK_Option), .maskAlternate)]
        var held: CGEventFlags = []
        func post(_ key: CGKeyCode, down: Bool) {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)
            event?.flags = held
            event?.post(tap: .cghidEventTap)
        }
        for (key, flag) in modifiers {
            held.insert(flag)
            post(key, down: true)
        }
        post(CGKeyCode(kVK_Space), down: true)
        post(CGKeyCode(kVK_Space), down: false)
        for (key, flag) in modifiers.reversed() {
            held.remove(flag)
            post(key, down: false)
        }
    }
}

enum Sources {
    static func enabled() -> [String] {
        list([
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsSelectCapable: true,
            kTISPropertyInputSourceIsEnabled: true,
        ]).compactMap(id)
    }

    static func current() -> String? {
        id(of: TISCopyCurrentKeyboardInputSource().takeRetainedValue())
    }

    static func select(_ id: String) {
        if let source = list([kTISPropertyInputSourceID: id]).first { TISSelectInputSource(source) }
    }

    static func short(_ id: String) -> String {
        id.components(separatedBy: ".").last ?? id
    }

    private static func list(_ properties: [CFString: Any]) -> [TISInputSource] {
        TISCreateInputSourceList(properties as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] ?? []
    }

    private static func id(of source: TISInputSource) -> String? {
        TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            .map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }
}

let app = NSApplication.shared
let probe = Probe()
app.delegate = probe
app.setActivationPolicy(.regular)
app.run()
