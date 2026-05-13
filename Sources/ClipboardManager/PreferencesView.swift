import AppKit
import SwiftUI

// MARK: - Window Controller

@MainActor
final class PreferencesWindowController {
    private static var window: NSWindow?

    static func show() {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Clipboard Manager — Preferences"
        w.isReleasedWhenClosed = false
        w.center()
        w.contentView = NSHostingView(rootView: PreferencesView())
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - View

struct PreferencesView: View {
    @ObservedObject private var prefs = PreferencesManager.shared
    @ObservedObject private var store = ClipboardStore.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Global Hotkey") {
                    Text(prefs.hotkey.displayString)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
                Text("Hotkey customization: use the setup wizard to re-run configuration.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Hotkey")
            }

            Section {
                LabeledContent("Maximum items") {
                    Stepper("\(prefs.maxHistory)", value: $prefs.maxHistory, in: 10...500, step: 10)
                }

                Button("Clear All History") {
                    store.clear()
                }
                .foregroundStyle(.red)
                .buttonStyle(.plain)
            } header: {
                Text("History")
            }

            Section {
                Toggle("Launch at login", isOn: $prefs.launchAtLogin)
                Toggle("Sync text history to iCloud Drive", isOn: $prefs.iCloudSyncEnabled)
                    .help("Writes to ~/iCloud Drive/ClipboardManager/history.json")
            } header: {
                Text("General")
            }

            Section {
                HStack(spacing: 12) {
                    PermissionStatus(check: { AXIsProcessTrusted() }, label: "Accessibility")
                    Button("Open") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 12) {
                    PermissionStatus(check: { CGPreflightListenEventAccess() }, label: "Input Monitoring")
                    Button("Open") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } header: {
                Text("Permissions")
            }

            Section {
                Button("Open Setup Wizard…") {
                    SetupWizardWindowController.show()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            } header: {
                Text("Help")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 380)
    }
}

// MARK: - Permission status indicator

private struct PermissionStatus: View {
    let check: () -> Bool
    let label: String

    @State private var granted = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)
            Text(label)
                .font(.system(size: 13))
            Spacer()
        }
        .onReceive(timer) { _ in granted = check() }
        .onAppear { granted = check() }
    }
}
