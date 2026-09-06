import AppKit
import SwiftUI

@MainActor
final class HUDPanel: NSPanel {
    static let size = NSSize(width: 300, height: 64)
    static let bottomMargin: CGFloat = 110
    static let fadeDuration: TimeInterval = 0.15

    init(model: HUDModel) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        contentView = NSHostingView(rootView: HUDView(model: model))
    }

    func present() {
        setFrameOrigin(originOnActiveScreen())
        if isVisible && alphaValue == 1 { return }
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            animator().alphaValue = 1
        }
    }

    func dismiss() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeDuration
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, alphaValue == 0 else { return }
            orderOut(nil)
        })
    }

    private func originOnActiveScreen() -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_440, height: 900)
        return NSPoint(
            x: frame.midX - Self.size.width / 2,
            y: frame.minY + Self.bottomMargin
        )
    }
}
