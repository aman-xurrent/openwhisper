import Carbon.HIToolbox
import Foundation

final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private static let signature: OSType = 0x5354_5950

    private struct Registration {
        let combo: KeyCombo
        let handler: () -> Void
        var reference: EventHotKeyRef?
    }

    private var eventHandler: EventHandlerRef?
    private var nextIdentifier: UInt32 = 1
    private var registrations: [UInt32: Registration] = [:]
    private(set) var isPaused = false

    private init() {
        installEventHandler()
    }

    @discardableResult
    func register(_ combo: KeyCombo, handler: @escaping () -> Void) -> UInt32? {
        let identifier = nextIdentifier
        nextIdentifier += 1
        var registration = Registration(combo: combo, handler: handler, reference: nil)
        if !isPaused {
            guard let reference = registerWithCarbon(combo, identifier: identifier) else { return nil }
            registration.reference = reference
        }
        registrations[identifier] = registration
        return identifier
    }

    func unregister(_ identifier: UInt32) {
        guard let registration = registrations.removeValue(forKey: identifier) else { return }
        if let reference = registration.reference {
            UnregisterEventHotKey(reference)
        }
    }

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        for (identifier, registration) in registrations {
            guard let reference = registration.reference else { continue }
            UnregisterEventHotKey(reference)
            registrations[identifier]?.reference = nil
        }
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        for (identifier, registration) in registrations where registration.reference == nil {
            registrations[identifier]?.reference = registerWithCarbon(registration.combo, identifier: identifier)
        }
    }

    private func registerWithCarbon(_ combo: KeyCombo, identifier: UInt32) -> EventHotKeyRef? {
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr else {
            Log.hotkey.error("RegisterEventHotKey failed for \(combo.displayString): \(status)")
            return nil
        }
        return reference
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                return center.handle(event)
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
        if status != noErr {
            Log.hotkey.error("InstallEventHandler failed: \(status)")
        }
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == Self.signature,
              let registration = registrations[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }
        DispatchQueue.main.async(execute: registration.handler)
        return noErr
    }
}
