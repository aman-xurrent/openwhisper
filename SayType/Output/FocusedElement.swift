import AppKit
import ApplicationServices

struct FocusedElement {
    static let editableRoles: Set<String> = [
        kAXTextFieldRole,
        kAXTextAreaRole,
        kAXComboBoxRole,
        "AXSearchField",
    ]

    let element: AXUIElement
    let role: String?
    let subrole: String?

    static func current() -> FocusedElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value)
        guard status == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        let element = unsafeBitCast(value, to: AXUIElement.self)
        return FocusedElement(
            element: element,
            role: stringAttribute(kAXRoleAttribute, of: element),
            subrole: stringAttribute(kAXSubroleAttribute, of: element)
        )
    }

    var isSecure: Bool {
        subrole == kAXSecureTextFieldSubrole
    }

    var acceptsText: Bool {
        if isSecure { return false }
        if let role, Self.editableRoles.contains(role) { return true }
        return isSettable(kAXSelectedTextAttribute)
    }

    private func isSettable(_ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let status = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return status == .success && settable.boolValue
    }

    private static func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value, CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        return value as? String
    }
}
