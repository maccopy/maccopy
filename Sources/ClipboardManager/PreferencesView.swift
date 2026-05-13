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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
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
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        Form {
            // MARK: Hotkey
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
                Text("Change hotkey via the Setup Wizard.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Hotkey")
            }

            // MARK: History
            Section {
                LabeledContent("Maximum items") {
                    Stepper("\(prefs.maxHistory)", value: $prefs.maxHistory, in: 10...1000, step: 10)
                }
                Button("Clear All History") {
                    store.clear()
                }
                .foregroundStyle(.red)
                .buttonStyle(.plain)
            } header: {
                Text("History")
            }

            // MARK: Appearance
            Section {
                LabeledContent("Theme") {
                    Picker("", selection: $prefs.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                LabeledContent("Row density") {
                    Picker("", selection: $prefs.rowDensity) {
                        ForEach(RowDensity.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                LabeledContent("Popover width") {
                    HStack(spacing: 8) {
                        Slider(value: $prefs.popoverWidth, in: 360...600, step: 20)
                            .frame(width: 140)
                        Text("\(Int(prefs.popoverWidth)) px")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 54, alignment: .leading)
                    }
                }

                Toggle("Glass / blur effect", isOn: $prefs.useGlassEffect)
                Toggle("Show type icon", isOn: $prefs.showTypeIcon)
                Toggle("Show timestamps", isOn: $prefs.showTimestamps)
                Toggle("Show character count", isOn: $prefs.showCharCount)
            } header: {
                Text("Appearance")
            }

            // MARK: General
            Section {
                Toggle("Launch at login", isOn: $prefs.launchAtLogin)
                Toggle("Sync text history to iCloud Drive", isOn: $prefs.iCloudSyncEnabled)
                    .help("Writes to ~/iCloud Drive/ClipboardManager/history.json")
            } header: {
                Text("General")
            }

            // MARK: Updates
            Section {
                Toggle("Check for updates automatically", isOn: $prefs.autoCheckUpdates)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if updater.updateAvailable, let release = updater.latestRelease {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.system(size: 12))
                                Text("v\(release.versionDisplay) available")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)
                                if let date = release.formattedDate {
                                    Text("· \(date)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        } else if updater.isChecking {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.mini)
                                Text("Checking…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } else if let err = updater.checkError {
                            Text("Check failed: \(err)")
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        } else {
                            Text("v\(UpdateChecker.currentVersion) — up to date")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if updater.updateAvailable {
                        Button("Changelog") {
                            updater.showChangelog = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Download") {
                            updater.openReleasePage()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("Check Now") {
                            Task { await updater.check() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(updater.isChecking)
                    }
                }
            } header: {
                Text("Updates")
            }

            // MARK: Permissions
            Section {
                HStack(spacing: 12) {
                    PermissionStatus(
                        check: { PermissionRequester.accessibilityGranted },
                        label: "Accessibility"
                    )
                    Button(PermissionRequester.accessibilityGranted ? "Settings" : "Request") {
                        if PermissionRequester.accessibilityGranted {
                            NSWorkspace.shared.open(
                                URL(
                                    string:
                                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                                )!)
                        } else {
                            PermissionRequester.requestAccessibility()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                HStack(spacing: 12) {
                    PermissionStatus(
                        check: { PermissionRequester.inputMonitoringGranted },
                        label: "Input Monitoring"
                    )
                    Button(PermissionRequester.inputMonitoringGranted ? "Settings" : "Request") {
                        if PermissionRequester.inputMonitoringGranted {
                            NSWorkspace.shared.open(
                                URL(
                                    string:
                                        "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                                )!)
                        } else {
                            PermissionRequester.requestInputMonitoring()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } header: {
                Text("Permissions")
            }

            // MARK: Help
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
        .frame(width: 520, height: 560)
        .sheet(isPresented: $updater.showChangelog) {
            if let release = updater.latestRelease {
                ChangelogView(release: release)
            }
        }
    }
}

// MARK: - Permission Status Indicator

private struct PermissionStatus: View {
    let check: () -> Bool
    let label: String

    @State private var granted = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)
                .symbolRenderingMode(.multicolor)
            Text(label)
                .font(.system(size: 13))
            Spacer()
        }
        .onReceive(timer) { _ in granted = check() }
        .onAppear { granted = check() }
    }
}
