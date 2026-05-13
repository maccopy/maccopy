import Carbon.HIToolbox

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let callback: () -> Void
    private let combo: KeyCombo

    init(combo: KeyCombo, callback: @escaping () -> Void) {
        self.combo = combo
        self.callback = callback
    }

    func register() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let ptr = userData else { return noErr }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { mgr.callback() }
                return noErr
            },
            1, &spec, selfPtr, &handler
        )

        let keyID = EventHotKeyID(signature: OSType(0x636C6970), id: 1)
        RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            keyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let h = handler { RemoveEventHandler(h) }
        hotKeyRef = nil
        handler = nil
    }

    deinit { unregister() }
}
