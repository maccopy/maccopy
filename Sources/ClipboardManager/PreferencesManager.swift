import Carbon.HIToolbox
import Foundation

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
    }

    private func save() {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: "hotkey")
        }
        defaults.set(maxHistory, forKey: "maxHistory")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(iCloudSyncEnabled, forKey: "iCloudSyncEnabled")
        defaults.set(hasCompletedSetup, forKey: "hasCompletedSetup")
    }

    private func applyLaunchAtLogin() {
        let bundleID = "com.fernandohaeser.clipboardmanager"
        let plistPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(bundleID).plist"
        let cmd =
            launchAtLogin ? "launchctl load -w '\(plistPath)'" : "launchctl unload '\(plistPath)'"
        let p = Process()
        p.launchPath = "/bin/sh"
        p.arguments = ["-c", cmd]
        try? p.run()
    }
}
