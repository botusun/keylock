import SwiftUI

@main
struct KeyLockApp: App {
    @StateObject private var locker = KeyboardLocker()

    var body: some Scene {
        WindowGroup {
            ContentView(locker: locker)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 320)
    }
}
