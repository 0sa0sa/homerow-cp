import Carbon.HIToolbox
import AppKit
import HomerowCPCore

final class HotkeyManager {
    private static var nextHotKeyID: UInt32 = 1

    var onActivate: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID: UInt32

    init() {
        hotKeyID = Self.nextHotKeyID
        Self.nextHotKeyID += 1
    }

    func register(combo: KeyCombo) {
        let eventHotKeyID = EventHotKeyID(signature: OSType(0x484D5257), id: hotKeyID)
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            var receivedID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &receivedID
            )
            guard status == noErr else { return OSStatus(eventNotHandledErr) }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            guard receivedID.id == manager.hotKeyID else { return OSStatus(eventNotHandledErr) }
            manager.onActivate?()
            return noErr
        }, 1, &eventSpec, selfPtr, &eventHandlerRef)

        RegisterEventHotKey(combo.keyCode, combo.modifiers, eventHotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        hotKeyRef = nil
        eventHandlerRef = nil
    }
}
