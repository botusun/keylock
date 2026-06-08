import SwiftUI
import AppKit

private class WindowDelegate: NSObject, NSWindowDelegate {
    let locker: KeyboardLocker

    init(locker: KeyboardLocker) { self.locker = locker }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        !locker.isLocked
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let locker: KeyboardLocker

    func makeCoordinator() -> WindowDelegate { WindowDelegate(locker: locker) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.delegate = context.coordinator
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject var locker: KeyboardLocker

    var body: some View {
        ZStack {
            WindowBackground(isLocked: locker.isLocked, accentColor: accentColor)

            VStack(spacing: 22) {
                header

                KeyboardPanel(isLocked: locker.isLocked, accentColor: accentColor)
                    .frame(height: 162)
                    .animation(.easeInOut(duration: 0.24), value: locker.isLocked)

                VStack(spacing: 7) {
                    Text(locker.isLocked ? "Keyboard Locked" : "Keyboard Ready")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(locker.isLocked ? "Input is blocked system-wide." : "Keyboard input is available.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    locker.toggleLock()
                } label: {
                    Label(locker.isLocked ? "Unlock Keyboard" : "Lock Keyboard",
                          systemImage: locker.isLocked ? "lock.open.fill" : "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LockButtonStyle(accentColor: accentColor))
                .animation(.easeInOut(duration: 0.2), value: locker.isLocked)
                .accessibilityHint(locker.isLocked ? "Restores keyboard input" : "Blocks keyboard input")

                if !locker.hasAccessibilityPermission {
                    PermissionCallout(action: locker.openAccessibilitySettings)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(28)
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .background(WindowAccessor(locker: locker))
    }

    private var accentColor: Color {
        locker.isLocked
            ? Color(red: 0.18, green: 0.62, blue: 0.42)
            : Color(red: 0.96, green: 0.46, blue: 0.16)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(0.15))

                Image(systemName: "keyboard.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("KeyLock")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(locker.hasAccessibilityPermission ? "Accessibility enabled" : "Setup required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            StatusPill(
                title: locker.isLocked ? "Locked" : "Ready",
                systemImage: locker.isLocked ? "lock.fill" : "checkmark.circle.fill",
                tint: accentColor
            )
        }
    }
}

#Preview {
    ContentView(locker: KeyboardLocker())
}

private struct WindowBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let isLocked: Bool
    let accentColor: Color

    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(accentColor)
                .frame(height: 4)
                .opacity(0.78)
        }
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.08, green: 0.09, blue: 0.10),
                Color(red: 0.13, green: 0.14, blue: 0.13),
                accentColor.opacity(isLocked ? 0.20 : 0.14)
            ]
        }

        return [
            Color(red: 0.97, green: 0.98, blue: 0.98),
            Color(red: 0.91, green: 0.94, blue: 0.95),
            accentColor.opacity(isLocked ? 0.16 : 0.10)
        ]
    }
}

private struct StatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct KeyboardPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    let isLocked: Bool
    let accentColor: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(panelFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .shadow(color: shadowColor, radius: 18, x: 0, y: 10)

            KeyboardDeck(isLocked: isLocked, accentColor: accentColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)

            StatusMedallion(isLocked: isLocked, accentColor: accentColor)
                .padding(14)
        }
    }

    private var panelFill: LinearGradient {
        let activeStart = colorScheme == .dark
            ? Color(red: 0.20, green: 0.22, blue: 0.24)
            : Color.white.opacity(0.94)
        let activeEnd = colorScheme == .dark
            ? Color(red: 0.13, green: 0.15, blue: 0.16)
            : Color(red: 0.88, green: 0.92, blue: 0.94)

        return LinearGradient(
            colors: [
                activeStart,
                activeEnd,
                accentColor.opacity(isLocked ? 0.24 : 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.30) : .black.opacity(0.10)
    }
}

private struct KeyboardDeck: View {
    let isLocked: Bool
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<10, id: \.self) { _ in
                    KeyCap(width: 20, isLocked: isLocked, accentColor: accentColor)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<9, id: \.self) { _ in
                    KeyCap(width: 20, isLocked: isLocked, accentColor: accentColor)
                }
            }

            HStack(spacing: 8) {
                KeyCap(width: 34, isLocked: isLocked, accentColor: accentColor)
                KeyCap(width: 106, isLocked: isLocked, accentColor: accentColor)
                KeyCap(width: 34, isLocked: isLocked, accentColor: accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isLocked ? 0.74 : 1)
    }
}

private struct KeyCap: View {
    @Environment(\.colorScheme) private var colorScheme
    let width: CGFloat
    let isLocked: Bool
    let accentColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .frame(width: width, height: 18)
    }

    private var fillColor: Color {
        if isLocked {
            return accentColor.opacity(colorScheme == .dark ? 0.30 : 0.18)
        }

        return colorScheme == .dark ? .white.opacity(0.16) : .white.opacity(0.82)
    }

    private var strokeColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.06)
    }
}

private struct StatusMedallion: View {
    let isLocked: Bool
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accentColor)
                .shadow(color: accentColor.opacity(0.32), radius: 10, x: 0, y: 5)

            Image(systemName: isLocked ? "lock.fill" : "checkmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

private struct LockButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: accentColor.opacity(configuration.isPressed ? 0.10 : 0.30),
                    radius: configuration.isPressed ? 4 : 12,
                    x: 0,
                    y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.55)
    }
}

private struct PermissionCallout: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.98, green: 0.64, blue: 0.16))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessibility Access Needed")
                        .font(.subheadline.weight(.semibold))

                    Text("Enable KeyLock in System Settings before locking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: action) {
                Label("Open System Settings", systemImage: "gearshape.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
