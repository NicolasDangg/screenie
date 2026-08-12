import Carbon

final class GlobalHotKey: @unchecked Sendable {
    static let keyCode = UInt32(kVK_Space)
    static let modifiers = UInt32(optionKey)

    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: @Sendable @MainActor () -> Void

    init(action: @escaping @Sendable @MainActor () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let owner = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in owner.action() }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandler
        )
        RegisterEventHotKey(
            Self.keyCode,
            Self.modifiers,
            EventHotKeyID(signature: 0x53534745, id: 1),
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
