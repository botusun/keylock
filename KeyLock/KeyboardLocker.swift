import Cocoa
import ApplicationServices

class KeyboardLocker: ObservableObject {
    @Published var isLocked = false
    @Published var hasAccessibilityPermission = AXIsProcessTrusted()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    init() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let trusted = AXIsProcessTrusted()
            DispatchQueue.main.async { self?.hasAccessibilityPermission = trusted }
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

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
                              | (1 << CGEventType.keyUp.rawValue)
                              | (1 << CGEventType.flagsChanged.rawValue)
                              | (1 << 14) // NX_SYSDEFINED: brightness, volume, media keys

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, _, _ in nil },
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
