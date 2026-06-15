import Cocoa
import ApplicationServices
import IOKit
import IOKit.hidsystem

// MARK: - Caps Lock control (IOKit HID)

/// Caps Lock is toggled in the IOKit HID layer *below* a CGEvent tap, so simply
/// swallowing its `flagsChanged` event does not stop the physical lock state from
/// flipping. We force the desired state back through IOHIDSystem instead.
private func openHIDService() -> io_connect_t {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
    guard service != 0 else { return 0 }
    defer { IOObjectRelease(service) }

    var connect: io_connect_t = 0
    guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else {
        return 0
    }
    return connect
}

private func getCapsLockState() -> Bool {
    let connect = openHIDService()
    guard connect != 0 else { return false }
    defer { IOServiceClose(connect) }

    var state = false
    IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state)
    return state
}

private func setCapsLockState(_ on: Bool) {
    let connect = openHIDService()
    guard connect != 0 else { return }
    defer { IOServiceClose(connect) }

    IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), on)
}

/// The Caps Lock state to hold while locked (whatever it was when locking began).
private var heldCapsLockState = false

/// Virtual keycode for the Caps Lock key.
private let kCapsLockKeyCode: Int64 = 57

private let eventTapCallback: CGEventTapCallBack = { _, type, event, _ in
    // Re-assert the held Caps Lock state if the user pressed Caps Lock.
    if type == .flagsChanged, event.getIntegerValueField(.keyboardEventKeycode) == kCapsLockKeyCode {
        setCapsLockState(heldCapsLockState)
    }
    // Swallow every key/modifier/system event so nothing reaches any app.
    return nil
}

class KeyboardLocker: ObservableObject {
    @Published var isLocked = false
    @Published var hasAccessibilityPermission = AXIsProcessTrusted()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    init() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let trusted = AXIsProcessTrusted()
            DispatchQueue.main.async {
                self?.hasAccessibilityPermission = trusted
                if trusted {
                    self?.permissionTimer?.invalidate()
                    self?.permissionTimer = nil
                }
            }
        }
    }

    deinit {
        permissionTimer?.invalidate()
        if isLocked { unlock() }
    }

    func toggleLock() {
        isLocked ? unlock() : lock()
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    private func lock() {
        guard AXIsProcessTrusted() else {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            return
        }

        // Remember the current Caps Lock state and hold it for the lock duration.
        heldCapsLockState = getCapsLockState()

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
                              | (1 << CGEventType.keyUp.rawValue)
                              | (1 << CGEventType.flagsChanged.rawValue)
                              | (1 << 14) // NX_SYSDEFINED: brightness, volume, media keys

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: nil
        ) else { return }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isLocked = true
        NSApp.mainWindow?.level = .floating
    }

    private func unlock() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isLocked = false
        NSApp.mainWindow?.level = .normal
    }
}
