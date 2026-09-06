import AppKit
import SwiftUI

struct HotKeyRecorderView: NSViewRepresentable {
    static let size = NSSize(width: 160, height: 24)

    @Binding var combo: KeyCombo
    let hotKeyCenter: HotKeyCenter

    func makeNSView(context: Context) -> HotKeyRecorderNSView {
        let view = HotKeyRecorderNSView()
        view.combo = combo
        view.onRecordingChanged = { [hotKeyCenter] isRecording in
            isRecording ? hotKeyCenter.pause() : hotKeyCenter.resume()
        }
        view.onComboChanged = { newCombo in
            combo = newCombo
        }
        return view
    }

    func updateNSView(_ nsView: HotKeyRecorderNSView, context: Context) {
        nsView.combo = combo
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: HotKeyRecorderNSView, context: Context) -> CGSize? {
        Self.size
    }
}

final class HotKeyRecorderNSView: NSView {
    static let cornerRadius: CGFloat = 6
    static let recordingPrompt = "Press shortcut…"

    var combo: KeyCombo = .defaultDictation {
        didSet { needsDisplay = true }
    }
    var onRecordingChanged: ((Bool) -> Void)?
    var onComboChanged: ((KeyCombo) -> Void)?

    private var isRecording = false {
        didSet {
            guard oldValue != isRecording else { return }
            onRecordingChanged?(isRecording)
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { HotKeyRecorderView.size }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        handle(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else { return false }
        handle(event)
        return true
    }

    private func handle(_ event: NSEvent) {
        let candidate = KeyCombo(event: event)
        if candidate == .escape {
            endRecording()
            return
        }
        guard candidate.isUsableAsGlobalShortcut else {
            NSSound.beep()
            return
        }
        combo = candidate
        onComboChanged?(candidate)
        endRecording()
    }

    private func endRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()

        let text = isRecording ? Self.recordingPrompt : combo.displayString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]
        let size = text.size(withAttributes: attributes)
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        text.draw(at: origin, withAttributes: attributes)
    }
}
