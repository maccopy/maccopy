import AppKit
import Carbon.HIToolbox
import Foundation
import SwiftUI

struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32  // Carbon modifier flags

    static let `default` = KeyCombo(
        keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += keyCodeName(keyCode)
        return s
    }

    private func keyCodeName(_ code: UInt32) -> String {
        let table: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        ]
        return table[Int(code)] ?? "Key\(code)"
    }
}

enum AppearanceMode: String, Codable, CaseIterable {
    case light, dark

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum ItemFontDesign: String, Codable, CaseIterable {
    case `default`, monospaced, rounded, serif

    var displayName: String {
        switch self {
        case .default: return "System"
        case .monospaced: return "Monospaced"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .default: return .default
        case .monospaced: return .monospaced
        case .rounded: return .rounded
        case .serif: return .serif
        }
    }
}

enum StatusBarIconStyle: String, Codable, CaseIterable {
    case maccopy, clipboard, doc, paste, scissors, terminal

    var displayName: String {
        switch self {
        case .maccopy: return "Maccopy"
        case .clipboard: return "Clipboard"
        case .doc: return "Document"
        case .paste: return "Paste"
        case .scissors: return "Scissors"
        case .terminal: return "Terminal"
        }
    }

    var symbolName: String {
        switch self {
        case .maccopy: return "doc.on.clipboard.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .doc: return "doc.fill"
        case .paste: return "clipboard.fill"
        case .scissors: return "scissors"
        case .terminal: return "terminal.fill"
        }
    }
}

enum SearchBarStyle: String, Codable, CaseIterable {
    case minimal, subtle, accentFill

    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .subtle: return "Subtle"
        case .accentFill: return "Accent Fill"
        }
    }
}

enum AccentColorTheme: String, Codable, CaseIterable {
    case blue, purple, indigo, pink, orange, mint, teal, green, red

    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .indigo: return "Indigo"
        case .pink: return "Pink"
        case .orange: return "Orange"
        case .mint: return "Mint"
        case .teal: return "Teal"
        case .green: return "Green"
        case .red: return "Red"
        }
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .indigo: return .indigo
        case .pink: return .pink
        case .orange: return .orange
        case .mint: return .mint
        case .teal: return .teal
        case .green: return .green
        case .red: return .red
        }
    }
}

enum RowDensity: String, Codable, CaseIterable {
    case compact, comfortable, spacious

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .comfortable: return "Comfortable"
        case .spacious: return "Spacious"
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compact: return 5
        case .comfortable: return 8
        case .spacious: return 12
        }
    }

    var primaryFontSize: CGFloat {
        switch self {
        case .compact: return 11
        case .comfortable: return 12
        case .spacious: return 13
        }
    }
}

@MainActor
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    @Published var hotkey: KeyCombo { didSet { save() } }
    @Published var maxHistory: Int { didSet { save() } }
    @Published var launchAtLogin: Bool {
        didSet {
            applyLaunchAtLogin()
            save()
        }
    }
    @Published var iCloudSyncEnabled: Bool { didSet { save() } }
    @Published var hasCompletedSetup: Bool { didSet { save() } }

    // Appearance
    @Published var appearanceMode: AppearanceMode {
        didSet {
            applyAppearance()
            save()
        }
    }
    @Published var rowDensity: RowDensity { didSet { save() } }
    @Published var showTimestamps: Bool { didSet { save() } }
    @Published var showCharCount: Bool { didSet { save() } }
    @Published var showTypeIcon: Bool { didSet { save() } }
    @Published var popoverWidth: Double { didSet { save() } }

    @Published var useGlassEffect: Bool { didSet { save() } }
    @Published var overlayOpacity: Double { didSet { save() } }
    @Published var accentColorTheme: AccentColorTheme { didSet { save() } }
    @Published var itemFontDesign: ItemFontDesign { didSet { save() } }
    @Published var itemFontSize: Double { didSet { save() } }
    @Published var showSelectionStripe: Bool { didSet { save() } }
    @Published var popoverHeight: Double { didSet { save() } }
    @Published var popoverCornerRadius: Double { didSet { save() } }
    @Published var statusBarIconStyle: StatusBarIconStyle {
        didSet { applyStatusBarIcon(); save() }
    }
    @Published var searchBarStyle: SearchBarStyle { didSet { save() } }

    // Updates
    @Published var autoCheckUpdates: Bool { didSet { save() } }

    private init() {
        if let data = defaults.data(forKey: "hotkey"),
            let combo = try? JSONDecoder().decode(KeyCombo.self, from: data)
        {
            hotkey = combo
        } else {
            hotkey = .default
        }
        let maxH = defaults.integer(forKey: "maxHistory")
        maxHistory = maxH > 0 ? maxH : 50
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        iCloudSyncEnabled = defaults.bool(forKey: "iCloudSyncEnabled")
        hasCompletedSetup = defaults.bool(forKey: "hasCompletedSetup")

        // Appearance
        if let raw = defaults.string(forKey: "appearanceMode"),
            let mode = AppearanceMode(rawValue: raw)
        {
            appearanceMode = mode
        } else {
            appearanceMode = .dark
        }
        if let raw = defaults.string(forKey: "rowDensity"),
            let density = RowDensity(rawValue: raw)
        {
            rowDensity = density
        } else {
            rowDensity = .comfortable
        }
        showTimestamps = defaults.object(forKey: "showTimestamps") as? Bool ?? true
        showCharCount = defaults.object(forKey: "showCharCount") as? Bool ?? true
        showTypeIcon = defaults.object(forKey: "showTypeIcon") as? Bool ?? true
        let w = defaults.double(forKey: "popoverWidth")
        popoverWidth = w > 0 ? w : 440

        useGlassEffect = defaults.object(forKey: "useGlassEffect") as? Bool ?? true
        let opacity = defaults.double(forKey: "overlayOpacity")
        overlayOpacity = opacity > 0 ? opacity : 0.95

        if let raw = defaults.string(forKey: "accentColorTheme"),
            let theme = AccentColorTheme(rawValue: raw)
        {
            accentColorTheme = theme
        } else {
            accentColorTheme = .blue
        }

        if let raw = defaults.string(forKey: "itemFontDesign"),
            let design = ItemFontDesign(rawValue: raw)
        {
            itemFontDesign = design
        } else {
            itemFontDesign = .default
        }
        let fSize = defaults.double(forKey: "itemFontSize")
        itemFontSize = fSize > 0 ? fSize : 12

        showSelectionStripe = defaults.object(forKey: "showSelectionStripe") as? Bool ?? true

        let pHeight = defaults.double(forKey: "popoverHeight")
        popoverHeight = pHeight > 0 ? pHeight : 540
        let pRadius = defaults.double(forKey: "popoverCornerRadius")
        popoverCornerRadius = pRadius > 0 ? pRadius : 14

        if let raw = defaults.string(forKey: "statusBarIconStyle"),
            let icon = StatusBarIconStyle(rawValue: raw)
        {
            statusBarIconStyle = icon
        } else {
            statusBarIconStyle = .maccopy
        }

        if let raw = defaults.string(forKey: "searchBarStyle"),
            let style = SearchBarStyle(rawValue: raw)
        {
            searchBarStyle = style
        } else {
            searchBarStyle = .minimal
        }

        // Updates
        autoCheckUpdates = defaults.object(forKey: "autoCheckUpdates") as? Bool ?? true
    }

    private func save() {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: "hotkey")
        }
        defaults.set(maxHistory, forKey: "maxHistory")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled")
        defaults.set(hasCompletedSetup, forKey: "hasCompletedSetup")
        defaults.set(appearanceMode.rawValue, forKey: "appearanceMode")
        defaults.set(rowDensity.rawValue, forKey: "rowDensity")
        defaults.set(showTimestamps, forKey: "showTimestamps")
        defaults.set(showCharCount, forKey: "showCharCount")
        defaults.set(showTypeIcon, forKey: "showTypeIcon")
        defaults.set(popoverWidth, forKey: "popoverWidth")
        defaults.set(useGlassEffect, forKey: "useGlassEffect")
        defaults.set(overlayOpacity, forKey: "overlayOpacity")
        defaults.set(accentColorTheme.rawValue, forKey: "accentColorTheme")
        defaults.set(itemFontDesign.rawValue, forKey: "itemFontDesign")
        defaults.set(itemFontSize, forKey: "itemFontSize")
        defaults.set(showSelectionStripe, forKey: "showSelectionStripe")
        defaults.set(popoverHeight, forKey: "popoverHeight")
        defaults.set(popoverCornerRadius, forKey: "popoverCornerRadius")
        defaults.set(statusBarIconStyle.rawValue, forKey: "statusBarIconStyle")
        defaults.set(searchBarStyle.rawValue, forKey: "searchBarStyle")
        defaults.set(autoCheckUpdates, forKey: "autoCheckUpdates")
    }

    func applyAppearance() {
        NSApp.appearance = appearanceMode.nsAppearance
        for window in NSApp.windows {
            window.appearance = appearanceMode.nsAppearance
        }
    }

    func applyStatusBarIcon() {
        AppDelegate.shared?.updateStatusBarIcon()
    }

    private func applyLaunchAtLogin() {
        let bundleID = "com.maccopy.maccopy"
        let plistPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(bundleID).plist"
        let cmd =
            launchAtLogin ? "launchctl load -w '\(plistPath)'" : "launchctl unload '\(plistPath)'"
        let p = Process()
        p.launchPath = "/bin/sh"
        p.arguments = ["-c", cmd]
        try? p.run()
    }
}
