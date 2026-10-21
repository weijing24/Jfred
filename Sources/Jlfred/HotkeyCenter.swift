import Carbon
import Foundation

final class HotkeyCenter: @unchecked Sendable {
    static let shared = HotkeyCenter()
    private var handlerRef: EventHandlerRef?
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private let lock = NSLock()

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        installIfNeeded()
        unregister(id: id)
        lock.lock()
        handlers[id] = handler
        lock.unlock()
        var ref: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: 0x4A4C4652, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            lock.lock()
            handlers[id] = nil
            lock.unlock()
            return false
        }
        lock.lock()
        refs[id] = ref
        lock.unlock()
        return true
    }

    func unregister(id: UInt32) {
        lock.lock()
        let ref = refs.removeValue(forKey: id)
        handlers[id] = nil
        lock.unlock()
        if let ref { UnregisterEventHotKey(ref) }
    }

    fileprivate func fire(_ id: UInt32) {
        lock.lock()
        let handler = handlers[id]
        lock.unlock()
        handler?()
    }

    private func installIfNeeded() {
        lock.lock()
        let already = handlerRef != nil
        lock.unlock()
        if already { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var installed: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), hotkeyCallback, 1, &spec, nil, &installed)
        lock.lock()
        handlerRef = installed
        lock.unlock()
    }
}

private let hotkeyCallback: EventHandlerUPP = { _, event, _ in
    guard let event else { return noErr }
    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    if status == noErr {
        let id = hotkeyID.id
        Task { @MainActor in
            HotkeyCenter.shared.fire(id)
        }
    }
    return noErr
}
