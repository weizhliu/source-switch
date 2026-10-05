import AppKit
import Carbon

/// macOS's own switcher (TextInputMenuUI's `-[InputSource activateForcibly:]`) never calls
/// `TISSelectInputSource`. It sends message 7 to the TSM port of the app with typing focus, and
/// that app selects the source in-process, which always reaches its input method. Typing focus
/// isn't always the frontmost app: a Spotlight-style panel takes keys without activating.
/// Uses private API, looked up at runtime so a missing symbol means falling back, not crashing.
enum FrontAppSelection {
    private static let selectInputSourceMessage: Int32 = 7
    private static let portName = "com.apple.tsm.portname" as CFString

    private typealias CreatePerProcessRemote = @convention(c) (CFAllocator?, CFString, pid_t) -> Unmanaged<CFMessagePort>?
    private typealias CreateFlattenedInputSource = @convention(c) (TISInputSource, UnsafeMutablePointer<Unmanaged<CFDictionary>?>) -> Bool
    private typealias InvalidateAllSelectedInputSourceState = @convention(c) () -> Void
    private typealias GetTypingFocusProcess = @convention(c) () -> pid_t

    /// RTLD_DEFAULT: every loaded image, not just the main executable's dependencies.
    private static let createPerProcessRemote = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CFMessagePortCreatePerProcessRemote")
        .map { unsafeBitCast($0, to: CreatePerProcessRemote.self) }
    private static let createFlattenedInputSource = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_CreateFlattenedInputSource")
        .map { unsafeBitCast($0, to: CreateFlattenedInputSource.self) }
    private static let getTypingFocusProcess = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "SLPSGetTypingFocusProcess")
        .map { unsafeBitCast($0, to: GetTypingFocusProcess.self) }
    private static let invalidateAllSelectedInputSourceState = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_InvalidateAllSelectedInputSourceState")
        .map { unsafeBitCast($0, to: InvalidateAllSelectedInputSourceState.self) }

    /// Returns false when the front app can't be asked, e.g. it's this app (switching in-process
    /// already works) or it has no TSM port; the caller then selects the source itself.
    static func ask(toSelect source: TISInputSource) -> Bool {
        guard let pid = typingFocusProcess(), pid != getpid(),
              let port = createPerProcessRemote?(nil, portName, pid)?.takeRetainedValue(),
              let payload = payload(for: source)
        else { return false }
        defer { CFMessagePortInvalidate(port) }
        // Waiting for the reply means the app has switched by the time this returns.
        let status = CFMessagePortSendRequest(port, selectInputSourceMessage, payload as CFData,
                                              0.5, 0.5, CFRunLoopMode.defaultMode.rawValue, nil)
        guard status == kCFMessagePortSuccess || status == kCFMessagePortReceiveTimeout else { return false }
        // This process caches the selection until it handles the change notification; drop the
        // cache so TISCopyCurrentKeyboardInputSource reports the switch right away.
        invalidateAllSelectedInputSourceState?()
        return true
    }

    private static func typingFocusProcess() -> pid_t? {
        if let pid = getTypingFocusProcess?(), pid > 0 { return pid }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    private static func payload(for source: TISInputSource) -> Data? {
        var flattened: Unmanaged<CFDictionary>?
        guard createFlattenedInputSource?(source, &flattened) == true,
              let flattened = flattened?.takeRetainedValue()
        else { return nil }
        return try? PropertyListSerialization.data(
            fromPropertyList: ["tsmInputSourceSelectedInpSrcKey": flattened], format: .xml, options: 0)
    }
}
