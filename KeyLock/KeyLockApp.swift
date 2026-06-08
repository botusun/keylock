import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct KeyLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var locker = KeyboardLocker()

    var body: some Scene {
        WindowGroup {
            ContentView(locker: locker)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 380, height: 440)
    }
}
