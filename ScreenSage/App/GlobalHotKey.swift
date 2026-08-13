import Carbon

final class GlobalHotKey: @unchecked Sendable {
    static let keyCode = UInt32(kVK_Space)
    static let modifiers = UInt32(optionKey)
    static let taskModifiers = UInt32(optionKey | cmdKey)

    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let registeredID: UInt32
    private let action: @Sendable @MainActor () -> Void

    static func shouldHandle(eventID: UInt32, registeredID: UInt32) -> Bool {
        eventID == registeredID
    }

    init(
        modifiers: UInt32 = GlobalHotKey.modifiers,
        id: UInt32 = 1,
        action: @escaping @Sendable @MainActor () -> Void
    ) {
        registeredID = id
        self.action = action
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let owner = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                var eventID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &eventID
                )
                guard status == noErr,
                      GlobalHotKey.shouldHandle(eventID: eventID.id, registeredID: owner.registeredID) else {
                    return OSStatus(eventNotHandledErr)
                }
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
            modifiers,
            EventHotKeyID(signature: 0x53534745, id: id),
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
