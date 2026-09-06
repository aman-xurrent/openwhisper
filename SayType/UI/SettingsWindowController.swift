import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let contentSize = NSSize(width: 600, height: 600)

    private let selection = SettingsSelection()

    init(preferences: Preferences, modelStore: ModelStore, hotKeyCenter: HotKeyCenter) {
        let rootView = SettingsView(
            preferences: preferences,
            modelStore: modelStore,
            selection: selection,
            hotKeyCenter: hotKeyCenter
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "SayType Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(Self.contentSize)
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(tab: SettingsTab? = nil) {
        if let tab {
            selection.tab = tab
        }
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum SettingsTab: Hashable {
    case general
    case model
    case correction
    case permissions
}

@MainActor
@Observable
final class SettingsSelection {
    var tab: SettingsTab = .general
}
