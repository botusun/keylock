import SwiftUI

struct ContentView: View {
    @ObservedObject var locker: KeyboardLocker

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: locker.isLocked ? "keyboard.fill" : "keyboard")
                .font(.system(size: 64))
                .foregroundColor(locker.isLocked ? .orange : .secondary)
                .animation(.easeInOut(duration: 0.2), value: locker.isLocked)

            VStack(spacing: 6) {
                Text(locker.isLocked ? "Keyboard Locked" : "Keyboard Active")
                    .font(.title2.bold())

                Text(locker.isLocked
                     ? "All key input is blocked — safe to wipe"
                     : "Click below to block all keyboard input")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                locker.toggleLock()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: locker.isLocked ? "lock.open.fill" : "lock.fill")
                    Text(locker.isLocked ? "Unlock Keyboard" : "Lock Keyboard")
                }
                .font(.headline)
                .frame(width: 200)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(locker.isLocked ? .green : .orange)
            .animation(.easeInOut(duration: 0.2), value: locker.isLocked)

            if !locker.hasAccessibilityPermission {
                VStack(spacing: 8) {
                    Divider()

                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Accessibility permission required")
                            .font(.caption)
                    }

                    Button("Open System Settings") {
                        locker.openAccessibilitySettings()
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
            }
        }
        .padding(32)
        .frame(width: 320)
    }
}

#Preview {
    ContentView(locker: KeyboardLocker())
}
