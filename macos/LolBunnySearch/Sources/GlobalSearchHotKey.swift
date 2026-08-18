import Carbon.HIToolbox
import Foundation
import OSLog

/// Identifies this app's registration so the shared keyboard event stream can be
/// filtered down to our own keystroke.
private let hotKeySignature = OSType(0x4C42_4E59)  // 'LBNY'
private let hotKeyIdentifier: UInt32 = 1

/// A system-wide keystroke that raises the search field.
///
/// Carbon's hot key API is the only system-wide keystroke on macOS that works
/// without a user-granted permission or a team identifier: `NSEvent`'s global
/// monitors need Accessibility access, and the App Intents route this replaced
/// needed a signing team before macOS would reach the handler.
@MainActor
final class GlobalSearchHotKey {
    static let shared = GlobalSearchHotKey()

    /// The combination as a user reads it, so the window can name the same
    /// keystroke this type registers.
    static let displayName = "\u{2325}\u{2318}L"

    /// Whether the system granted the combination, so the window can tell the
    /// user the keystroke is dead instead of leaving them guessing.
    private(set) var isRegistered = false

    private var hotKeyReference: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onPress: (() -> Void)?

    private init() {}

    /// Claims Option-Command-L for this process. Another app may already own the
    /// combination, so the result is reported through `isRegistered` rather than
    /// leaving a dead keystroke behind.
    func install(onPress: @escaping () -> Void) {
        self.onPress = onPress
        guard eventHandler == nil, hotKeyReference == nil else {
            return
        }

        var pressedEvent = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else {
                    return OSStatus(eventNotHandledErr)
                }
                var pressed = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressed
                )
                guard parameterStatus == noErr,
                      pressed.signature == hotKeySignature,
                      pressed.id == hotKeyIdentifier
                else {
                    return OSStatus(eventNotHandledErr)
                }
                // The callback is a C function pointer, so it cannot capture the
                // instance and hops back to the main actor through the singleton.
                Task { @MainActor in
                    GlobalSearchHotKey.shared.handlePress()
                }
                return noErr
            },
            1,
            &pressedEvent,
            nil,
            &eventHandler
        )
        guard handlerStatus == noErr else {
            LolBunnySearchLog.hotKey.error("Could not install the hot key event handler: \(handlerStatus)")
            return
        }

        let identifier = EventHotKeyID(signature: hotKeySignature, id: hotKeyIdentifier)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            UInt32(optionKey | cmdKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )
        isRegistered = registerStatus == noErr
        if isRegistered {
            LolBunnySearchLog.hotKey.info("Registered \(Self.displayName, privacy: .public) for search")
        } else {
            LolBunnySearchLog.hotKey.error("Could not register \(Self.displayName, privacy: .public): \(registerStatus)")
        }
    }

    private func handlePress() {
        onPress?()
    }
}
