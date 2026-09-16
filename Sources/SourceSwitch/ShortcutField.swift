import AppKit
import Carbon
import SwiftUI

struct ShortcutField: View {
    let source: InputSource
    let state: AppState
    @State private var capture = ShortcutCapture()

    private var shortcut: Shortcut? { state.shortcuts[source.id] }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Text(capture.isCapturing ? "Type shortcut" : shortcut?.description ?? "Record Shortcut")
                    .foregroundStyle(capture.isCapturing || shortcut == nil ? .secondary : .primary)
                    .frame(maxWidth: .infinity)

                if let shortcut, !capture.isCapturing {
                    Button("Remove \(shortcut.description)", systemImage: "xmark.circle.fill") {
                        state.assign(nil, to: source)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(capture.isCapturing ? Color.accentColor : Color.secondary.opacity(0.4),
                                  lineWidth: capture.isCapturing ? 2 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: toggleCapture)

            if let message = capture.rejectionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onDisappear(perform: capture.stop)
    }

    private func toggleCapture() {
        if capture.isCapturing {
            capture.stop()
            state.resumeHotKeys()
            return
        }
        state.suspendHotKeys()
        capture.start { result in
            switch result {
            case .captured(let shortcut): state.assign(shortcut, to: source)
            case .cleared: state.assign(nil, to: source)
            case .cancelled: state.resumeHotKeys()
            }
        }
    }
}

@Observable
private final class ShortcutCapture {
    enum Result { case captured(Shortcut), cleared, cancelled }

    private(set) var isCapturing = false
    private(set) var rejectionMessage: String?
    private var eventMonitor: Any?

    func start(_ finish: @escaping (Result) -> Void) {
        isCapturing = true
        rejectionMessage = nil
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handle(event, finish: finish)
        }
    }

    func stop() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        isCapturing = false
    }

    private func handle(_ event: NSEvent, finish: (Result) -> Void) -> NSEvent? {
        guard event.type == .keyDown else {
            stop()
            finish(.cancelled)
            return event
        }

        let isUnmodified = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.function).isEmpty
        switch (Int(event.keyCode), isUnmodified) {
        case (kVK_Escape, true):
            stop()
            finish(.cancelled)
        case (kVK_Delete, true), (kVK_ForwardDelete, true):
            stop()
            finish(.cleared)
        default:
            guard let shortcut = Shortcut(keyDownEvent: event) else {
                reject("Include ⌃, ⌥ or ⌘")
                return nil
            }
            guard !shortcut.isReservedBySystem else {
                reject("\(shortcut) is used by macOS")
                return nil
            }
            stop()
            finish(.captured(shortcut))
        }
        return nil
    }

    private func reject(_ message: String) {
        rejectionMessage = message
        NSSound.beep()
    }
}
