import AppKit

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let toggleItem = NSMenuItem()
    private let modelItem = NSMenuItem()
    private let settingsItem = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: ",")
    private let quitItem = NSMenuItem(title: "Quit OpenWhisper", action: nil, keyEquivalent: "q")

    var onToggle: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        buildMenu()
        statusItem.menu = menu
        update(phase: .idle, hotKey: .defaultDictation, modelName: nil)
    }

    func update(phase: AppCoordinator.Phase, hotKey: KeyCombo, modelName: String?) {
        statusItem.button?.image = image(for: phase)
        statusItem.button?.toolTip = "OpenWhisper (\(hotKey.displayString))"
        toggleItem.title = phase == .recording ? "Stop Dictation" : "Start Dictation"
        toggleItem.isEnabled = phase != .transcribing
        toggleItem.keyEquivalent = ""
        toggleItem.title += "  \(hotKey.displayString)"
        modelItem.title = modelName.map { "Model: \($0)" } ?? "No model downloaded"
    }

    private func buildMenu() {
        toggleItem.target = self
        toggleItem.action = #selector(toggleTapped)
        modelItem.isEnabled = false
        settingsItem.target = self
        settingsItem.action = #selector(settingsTapped)
        quitItem.target = self
        quitItem.action = #selector(quitTapped)

        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(modelItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        menu.autoenablesItems = false
    }

    private func image(for phase: AppCoordinator.Phase) -> NSImage? {
        switch phase {
        case .idle:
            let image = NSImage(systemSymbolName: "mic", accessibilityDescription: "OpenWhisper idle")
            image?.isTemplate = true
            return image
        case .recording:
            let configuration = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "OpenWhisper recording")?
                .withSymbolConfiguration(configuration)
            image?.isTemplate = false
            return image
        case .transcribing:
            let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "OpenWhisper transcribing")
            image?.isTemplate = true
            return image
        }
    }

    @objc private func toggleTapped() {
        onToggle?()
    }

    @objc private func settingsTapped() {
        onOpenSettings?()
    }

    @objc private func quitTapped() {
        onQuit?()
    }
}
