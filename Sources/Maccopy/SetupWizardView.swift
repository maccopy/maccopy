import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

// MARK: - Window Controller

@MainActor
final class SetupWizardWindowController {
    private static var window: NSWindow?

    static func show() {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Maccopy Setup"
        w.isReleasedWhenClosed = false
        w.center()
        w.contentView = NSHostingView(rootView: SetupWizardView(dismiss: { w.close() }))
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Wizard Steps

enum WizardStep: Int, CaseIterable {
    case welcome, accessibility, inputMonitoring, preferences, done

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        case .preferences: return "Preferences"
        case .done: return "All Set!"
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "doc.on.clipboard.fill"
        case .accessibility: return "hand.raised.fill"
        case .inputMonitoring: return "keyboard.fill"
        case .preferences: return "slider.horizontal.3"
        case .done: return "checkmark.seal.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome: return .blue
        case .accessibility: return .purple
        case .inputMonitoring: return .indigo
        case .preferences: return .teal
        case .done: return .green
        }
    }
}

// MARK: - Main View

struct SetupWizardView: View {
    let dismiss: () -> Void

    @State private var step: WizardStep = .welcome
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.top, 24)
                .padding(.horizontal, 40)

            Spacer()

            stepContent
                .padding(.horizontal, 52)

            Spacer()

            navigationButtons
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
        }
        .frame(width: 580, height: 460)
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(WizardStep.allCases.enumerated()), id: \.offset) { idx, s in
                Circle()
                    .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 9, height: 9)
                    .animation(.spring(duration: 0.3), value: step)

                if idx < WizardStep.allCases.count - 1 {
                    Rectangle()
                        .fill(s.rawValue < step.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(height: 2)
                        .animation(.spring(duration: 0.3), value: step)
                }
            }
        }
    }

    // MARK: - Step Content

    private var stepContent: some View {
        VStack(spacing: 18) {
            Image(systemName: step.icon)
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(step.iconColor)
                .symbolEffect(.bounce.up, value: step)

            Text(stepHeadline)
                .font(.system(size: 22, weight: .semibold))
                .multilineTextAlignment(.center)

            stepBody
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id(step)
    }

    private var stepHeadline: String {
        switch step {
        case .welcome: return "Welcome to Maccopy"
        case .accessibility: return "Grant Accessibility Access"
        case .inputMonitoring: return "Grant Input Monitoring Access"
        case .preferences: return "Customize Your Experience"
        case .done: return "You're All Set!"
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .welcome:
            Text("A lightweight clipboard history manager that lives in your menu bar. Keep track of everything you copy — text, images, and files.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

        case .accessibility:
            VStack(spacing: 14) {
                Text("Needed to simulate ⌘V so items paste directly into your active app.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    // Primary: trigger the system prompt that registers the app with TCC
                    Button("Request Accessibility Access") {
                        PermissionRequester.requestAccessibility()
                    }
                    .buttonStyle(.borderedProminent)

                    // Fallback: open settings manually (for re-enabling after denial)
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                PermissionRow(check: { AXIsProcessTrusted() }, label: "Accessibility")
            }

        case .inputMonitoring:
            VStack(spacing: 14) {
                Text("Needed to detect the global hotkey \(prefs.hotkey.displayString) from any application.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    // Primary: trigger the system prompt that registers the app with TCC
                    Button("Request Input Monitoring Access") {
                        PermissionRequester.requestInputMonitoring()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open System Settings") {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                PermissionRow(check: { CGPreflightListenEventAccess() }, label: "Input Monitoring")
            }

        case .preferences:
            VStack(alignment: .leading, spacing: 14) {
                preferenceRow("History size") {
                    Stepper("\(prefs.maxHistory) items", value: $prefs.maxHistory, in: 10...500, step: 10)
                        .font(.system(size: 13))
                }
                Divider()
                Toggle("Launch at login", isOn: $prefs.launchAtLogin)
                    .font(.system(size: 13))
                Divider()
                Toggle("Sync text history to iCloud Drive", isOn: $prefs.iCloudSyncEnabled)
                    .font(.system(size: 13))
            }
            .frame(maxWidth: 340)

        case .done:
            VStack(spacing: 8) {
                Text("Maccopy is running in your menu bar.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Label("Click icon to open", systemImage: "cursorarrow.click")
                    Label("Or press \(prefs.hotkey.displayString)", systemImage: "keyboard")
                }
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
        }
    }

    private func preferenceRow<V: View>(_ label: String, @ViewBuilder content: () -> V) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            content()
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if step != .welcome {
                Button("Back") {
                    withAnimation(.spring(duration: 0.35)) {
                        step = WizardStep(rawValue: step.rawValue - 1) ?? .welcome
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if step == .done {
                Button("Get Started") {
                    prefs.hasCompletedSetup = true
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            } else {
                Button(step == .preferences ? "Finish" : "Next") {
                    withAnimation(.spring(duration: 0.35)) {
                        step = WizardStep(rawValue: step.rawValue + 1) ?? .done
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            }
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let check: () -> Bool
    let label: String

    @State private var granted = false
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
            Text(granted ? "\(label): Granted ✓" : "\(label): Not yet granted")
                .font(.system(size: 12))
                .foregroundStyle(granted ? .primary : .secondary)
        }
        .onReceive(timer) { _ in granted = check() }
        .onAppear { granted = check() }
    }
}
