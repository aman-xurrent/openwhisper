import AppKit
import Carbon.HIToolbox

@MainActor
final class TextInserter {
    enum Outcome {
        case pasted(applicationName: String)
        case copied
    }

    static let pasteboardRestoreDelay: TimeInterval = 0.8

    private let pasteboard = NSPasteboard.general
    private var pendingRestore: DispatchWorkItem?

    func deliver(_ text: String) -> Outcome {
        guard canPasteIntoFocusedElement() else {
            copyToPasteboard(text)
            return .copied
        }

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        copyToPasteboard(text)
        let changeCountAfterWrite = pasteboard.changeCount

        guard postCommandV() else {
            Log.output.error("Could not post ⌘V, leaving the text on the clipboard")
            return .copied
        }
        scheduleRestore(of: snapshot, expectedChangeCount: changeCountAfterWrite)

        let applicationName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "the front app"
        return .pasted(applicationName: applicationName)
    }

    private func canPasteIntoFocusedElement() -> Bool {
        guard Permissions.isAccessibilityTrusted else {
            Log.output.info("Accessibility not granted, falling back to clipboard")
            return false
        }
        guard !IsSecureEventInputEnabled() else {
            Log.output.info("Secure input is active, falling back to clipboard")
            return false
        }
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }
        guard let focused = FocusedElement.current() else {
            Log.output.info("No focused element, falling back to clipboard")
            return false
        }
        let accepts = focused.acceptsText
        Log.output.info("Focused role \(focused.role ?? "nil") subrole \(focused.subrole ?? "nil") accepts text: \(accepts)")
        return accepts
    }

    func copy(_ text: String) {
        copyToPasteboard(text)
    }

    private func copyToPasteboard(_ text: String) {
        pendingRestore?.cancel()
        pendingRestore = nil
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func scheduleRestore(of snapshot: PasteboardSnapshot, expectedChangeCount: Int) {
        let pasteboard = self.pasteboard
        let work = DispatchWorkItem {
            guard pasteboard.changeCount == expectedChangeCount else { return }
            snapshot.restore(to: pasteboard)
        }
        pendingRestore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteboardRestoreDelay, execute: work)
    }
}
