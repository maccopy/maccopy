import AppKit
import ApplicationServices
import CoreGraphics

/// Handles registering the app with macOS TCC (Transparency, Consent, and Control).
///
/// Ad-hoc signed apps won't appear in System Settings → Privacy panes until they
/// actively trigger the TCC request APIs. These calls show a system dialog AND add
/// the app entry so the user can toggle it later.
enum PermissionRequester {

    // MARK: - Accessibility

    /// Triggers the "Allow Accessibility access?" system dialog.
    /// After the call the app appears in System Settings → Privacy → Accessibility
    /// regardless of whether the user approves or denies.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Input Monitoring

    /// Triggers the "Allow Input Monitoring?" system dialog.
    /// After the call the app appears in System Settings → Privacy → Input Monitoring.
    @discardableResult
    static func requestInputMonitoring() -> Bool {
        CGRequestListenEventAccess()
    }

    // MARK: - Status checks (non-prompting)

    static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static var inputMonitoringGranted: Bool {
        CGPreflightListenEventAccess()
    }
}
