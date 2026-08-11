import Carbon.HIToolbox
import Foundation
import os

enum GlobalHotKeyAction: Equatable {
    case openMenu
    case openSettings
    case launchSite(index: Int)
}

struct GlobalHotKeyRegistration: Equatable {
    let character: String
    let action: GlobalHotKeyAction
}

func globalHotKeyRegistrations(for sites: [Site]) -> [GlobalHotKeyRegistration] {
    let sanitizedSites = sanitizedShortcuts(for: sites)
    var registrations = [
        GlobalHotKeyRegistration(character: ".", action: .openMenu),
        GlobalHotKeyRegistration(character: ",", action: .openSettings),
    ]
    registrations.append(
        contentsOf: sanitizedSites.enumerated().compactMap { index, site in
            guard let shortcut = site.shortcut else { return nil }
            return GlobalHotKeyRegistration(
                character: shortcut, action: .launchSite(index: index))
        })
    return registrations
}

/// Registers only Chap's exact Option-key combinations with macOS.
///
/// Unlike an active CGEvent tap, Carbon hot keys do not place Chap in the path of
/// unrelated keyboard events.
final class GlobalHotKeyManager: NSObject {
    private enum Constants {
        static let signature: OSType = 0x4348_4150  // "CHAP"
        static let firstID: UInt32 = 1
    }

    private struct KeyboardLayoutSnapshot {
        let identifier: String
        let data: Data
    }

    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []
    private var actionsByID: [UInt32: GlobalHotKeyAction] = [:]
    private var registrations: [GlobalHotKeyRegistration] = []
    private var actionHandler: ((GlobalHotKeyAction) -> Void)?
    private var registeredKeyboardLayoutIdentifier: String?
    private var isObservingInputSource = false
    private var isConfigured = false

    func configure(
        sites: [Site],
        actionHandler: @escaping (GlobalHotKeyAction) -> Void
    ) {
        precondition(Thread.isMainThread)
        self.actionHandler = actionHandler
        registrations = globalHotKeyRegistrations(for: sites)
        isConfigured = true
        unregisterAllHotKeys()
        registeredKeyboardLayoutIdentifier = nil

        guard installEventHandlerIfNeeded() else { return }
        observeKeyboardInputSourceIfNeeded()
        registerCurrentHotKeys()
    }

    func stop() {
        precondition(Thread.isMainThread)
        isConfigured = false
        unregisterAllHotKeys()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if isObservingInputSource {
            DistributedNotificationCenter.default().removeObserver(self)
            isObservingInputSource = false
        }
        registeredKeyboardLayoutIdentifier = nil
        actionHandler = nil
    }

    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandler == nil else { return true }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else {
                return OSStatus(eventNotHandledErr)
            }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID)
            guard status == noErr else { return status }
            guard hotKeyID.signature == Constants.signature else {
                return OSStatus(eventNotHandledErr)
            }

            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData)
                .takeUnretainedValue()
            return manager.handleHotKey(id: hotKeyID.id)
        }

        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler)
        guard status == noErr, let handler else {
            Log.app.error(
                "Failed to install global hot key handler: status=\(status, privacy: .public)")
            return false
        }
        eventHandler = handler
        return true
    }

    private func observeKeyboardInputSourceIfNeeded() {
        guard !isObservingInputSource else { return }
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(keyboardInputSourceDidChange),
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil)
        isObservingInputSource = true
    }

    @objc private func keyboardInputSourceDidChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isConfigured else { return }
            self.refreshHotKeysForKeyboardLayoutChange()
        }
    }

    private func registerCurrentHotKeys() {
        precondition(Thread.isMainThread)
        guard let keyboardLayout = keyboardLayoutSnapshot() else {
            Log.app.error("Failed to read the current keyboard layout")
            return
        }
        registerHotKeys(using: keyboardLayout)
    }

    private func refreshHotKeysForKeyboardLayoutChange() {
        precondition(Thread.isMainThread)
        guard let keyboardLayout = keyboardLayoutSnapshot() else { return }
        guard keyboardLayout.identifier != registeredKeyboardLayoutIdentifier else { return }
        unregisterAllHotKeys()
        registerHotKeys(using: keyboardLayout)
    }

    private func registerHotKeys(using keyboardLayout: KeyboardLayoutSnapshot) {
        for (offset, registration) in registrations.enumerated() {
            guard
                let keyCode = keyCode(
                    for: registration.character, keyboardLayoutData: keyboardLayout.data)
            else {
                Log.app.error(
                    "No key code for global shortcut \(registration.character, privacy: .private)"
                )
                continue
            }

            let id = Constants.firstID + UInt32(offset)
            let hotKeyID = EventHotKeyID(signature: Constants.signature, id: id)
            var hotKey: EventHotKeyRef?
            let status = RegisterEventHotKey(
                keyCode,
                UInt32(optionKey),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKey)
            guard status == noErr, let hotKey else {
                Log.app.error(
                    "Failed to register global shortcut \(registration.character, privacy: .private): status=\(status, privacy: .public)"
                )
                continue
            }

            hotKeys.append(hotKey)
            actionsByID[id] = registration.action
        }

        registeredKeyboardLayoutIdentifier = keyboardLayout.identifier
        Log.app.info(
            "Registered \(self.hotKeys.count, privacy: .public) global hot keys")
    }

    private func unregisterAllHotKeys() {
        for hotKey in hotKeys {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll()
        actionsByID.removeAll()
    }

    private func handleHotKey(id: UInt32) -> OSStatus {
        guard let action = actionsByID[id], let actionHandler else {
            return OSStatus(eventNotHandledErr)
        }
        DispatchQueue.main.async {
            actionHandler(action)
        }
        return noErr
    }

    private func keyboardLayoutSnapshot() -> KeyboardLayoutSnapshot? {
        guard
            let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
            let identifierPointer = TISGetInputSourceProperty(
                source, kTISPropertyInputSourceID),
            let layoutDataPointer = TISGetInputSourceProperty(
                source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let identifier =
            Unmanaged<CFString>.fromOpaque(identifierPointer)
            .takeUnretainedValue() as String
        let layoutData =
            Unmanaged<CFData>.fromOpaque(layoutDataPointer)
            .takeUnretainedValue() as Data
        return KeyboardLayoutSnapshot(identifier: identifier, data: layoutData)
    }

    private func keyCode(for character: String, keyboardLayoutData: Data) -> UInt32? {
        keyboardLayoutData.withUnsafeBytes { buffer -> UInt32? in
            guard
                let keyboardLayout = buffer.baseAddress?.assumingMemoryBound(
                    to: UCKeyboardLayout.self)
            else { return nil }

            for keyCode in UInt16(0)..<UInt16(128) {
                guard
                    let translated = translatedCharacter(
                        for: keyCode, keyboardLayout: keyboardLayout)
                else { continue }
                if translated.uppercased() == character.uppercased() {
                    return UInt32(keyCode)
                }
            }
            return nil
        }
    }

    private func translatedCharacter(
        for keyCode: UInt16,
        keyboardLayout: UnsafePointer<UCKeyboardLayout>
    ) -> String? {
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters)
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}
