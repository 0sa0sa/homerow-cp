import AppKit
import CoreGraphics
import Foundation
import HomerowCPCore

final class InputTapController {
    enum Mode: Equatable {
        case idle
        case hints
        case scroll
    }

    var onKeyDown: ((Character, NSEvent.ModifierFlags) -> Void)?

    private(set) var mode: Mode = .idle
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var passthroughCombos: [KeyCombo] = []

    func registerPassthroughHotkeys(_ combos: [KeyCombo]) {
        passthroughCombos = combos
    }

    func enter(_ mode: Mode) {
        self.mode = mode
        installTapIfNeeded()
    }

    func exitToIdle() {
        mode = .idle
    }

    private func installTapIfNeeded() {
        guard eventTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<InputTapController>.fromOpaque(refcon).takeUnretainedValue()
                return controller.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else { return }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if matchesPassthrough(keyCode: keyCode, cgFlags: event.flags) {
            return Unmanaged.passUnretained(event)
        }

        guard mode != .idle else { return Unmanaged.passUnretained(event) }
        guard let nsEvent = NSEvent(cgEvent: event),
              let scalar = nsEvent.charactersIgnoringModifiers?.unicodeScalars.first else {
            return Unmanaged.passUnretained(event)
        }
        var flags: NSEvent.ModifierFlags = []
        if event.flags.contains(.maskShift) { flags.insert(.shift) }
        if event.flags.contains(.maskAlternate) { flags.insert(.option) }
        if event.flags.contains(.maskCommand) { flags.insert(.command) }
        if event.flags.contains(.maskControl) { flags.insert(.control) }
        onKeyDown?(Character(scalar), flags)
        return nil
    }

    private func matchesPassthrough(keyCode: Int64, cgFlags: CGEventFlags) -> Bool {
        for combo in passthroughCombos {
            guard Int64(combo.keyCode) == keyCode else { continue }
            var required: CGEventFlags = []
            if combo.modifiers & 0x100 != 0 { required.insert(.maskCommand) }
            if combo.modifiers & 0x200 != 0 { required.insert(.maskShift) }
            if combo.modifiers & 0x800 != 0 { required.insert(.maskAlternate) }
            if combo.modifiers & 0x1000 != 0 { required.insert(.maskControl) }
            if cgFlags.contains(required) { return true }
        }
        return false
    }
}
