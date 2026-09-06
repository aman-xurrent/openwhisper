import AVFoundation
import AppKit
import ApplicationServices

enum Permissions {
    private static let microphoneSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
    private static let accessibilitySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    static var microphoneStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    static var isMicrophoneAuthorized: Bool {
        microphoneStatus == .authorized
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openMicrophoneSettings() {
        NSWorkspace.shared.open(microphoneSettingsURL)
    }

    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(accessibilitySettingsURL)
    }
}
