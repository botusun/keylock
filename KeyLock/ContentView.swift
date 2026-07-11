import SwiftUI
import AppKit

// MARK: - Window plumbing

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
            guard let window = view.window else { return }
            window.delegate = context.coordinator
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Palette

private enum Palette {
    /// Hot rose — input is blocked.
    static let locked = Color(red: 1.00, green: 0.27, blue: 0.40)
    /// Azure — keyboard is live, ready to lock.
    static let ready = Color(red: 0.30, green: 0.61, blue: 1.00)
    /// Amber — permission warning.
    static let warn = Color(red: 1.00, green: 0.70, blue: 0.22)
}

// MARK: - Root view

struct ContentView: View {
    @ObservedObject var locker: KeyboardLocker

    private var accent: Color { locker.isLocked ? Palette.locked : Palette.ready }

    var body: some View {
        ZStack {
            PlateBackground(isLocked: locker.isLocked, accent: accent)

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 30)

                KeycapButton(isLocked: locker.isLocked, accent: accent) {
                    locker.toggleLock()
                }
                .accessibilityLabel(locker.isLocked ? "Unlock keyboard" : "Lock keyboard")
                .accessibilityHint(locker.isLocked ? "Restores keyboard input" : "Blocks keyboard input")

                Spacer(minLength: 26)

                statusBlock

                if !locker.hasAccessibilityPermission {
                    PermissionCard(action: locker.openAccessibilitySettings)
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 34) // clears the traffic lights — the title bar is hidden
            .padding(.bottom, 28)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: locker.isLocked)
        .animation(.easeInOut(duration: 0.25), value: locker.hasAccessibilityPermission)
        .background(WindowAccessor(locker: locker))
    }

    private var topBar: some View {
        HStack {
            Text("KEYLOCK")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            StatusChip(isLocked: locker.isLocked, accent: accent)
        }
    }

    private var statusBlock: some View {
        VStack(spacing: 7) {
            Text(locker.isLocked ? "Input Blocked" : "Ready to Lock")
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.interpolate)

            Text(locker.isLocked
                 ? "Press the key to restore typing"
                 : "Press the key to silence the keyboard")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    ContentView(locker: KeyboardLocker())
}

// MARK: - Keycap

/// A physical keyboard key resting in a recessed well. The cap sits raised while
/// the keyboard is live and stays pressed down while input is locked.
private struct KeycapButton: View {
    @Environment(\.colorScheme) private var scheme
    let isLocked: Bool
    let accent: Color
    let action: () -> Void

    @State private var glow = false

    private let wellSize: CGFloat = 176
    private let capSize: CGFloat = 138

    var body: some View {
        Button(action: action) {
            ZStack {
                well
                cap
            }
            .frame(width: wellSize, height: wellSize)
            .contentShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
        }
        .buttonStyle(KeycapPressStyle())
        .onAppear(perform: syncGlow)
        .onChange(of: isLocked) { _ in syncGlow() }
    }

    private var well: some View {
        RoundedRectangle(cornerRadius: 42, style: .continuous)
            .fill(
                LinearGradient(colors: wellColors, startPoint: .top, endPoint: .bottom)
            )
            .overlay(wellInnerShadow)
            .overlay(
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .strokeBorder(accent.opacity(isLocked ? 0.75 : 0.22), lineWidth: isLocked ? 1.8 : 1)
            )
            .shadow(color: accent.opacity(isLocked ? (glow ? 0.55 : 0.28) : 0.10),
                    radius: isLocked ? (glow ? 26 : 14) : 10)
    }

    // Darkened top lip inside the well so the cavity reads as recessed.
    private var wellInnerShadow: some View {
        RoundedRectangle(cornerRadius: 42, style: .continuous)
            .stroke(Color.black.opacity(scheme == .dark ? 0.55 : 0.18), lineWidth: 10)
            .blur(radius: 8)
            .offset(y: 5)
            .mask(RoundedRectangle(cornerRadius: 42, style: .continuous))
            .allowsHitTesting(false)
    }

    private var cap: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(colors: capColors, startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(scheme == .dark ? 0.22 : 0.9), .white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
            )
            .overlay(glyph)
            .frame(width: capSize, height: capSize)
            .offset(y: isLocked ? 7 : -5)
            .shadow(color: .black.opacity(scheme == .dark ? 0.6 : 0.25),
                    radius: isLocked ? 3 : 13,
                    y: isLocked ? 2 : 10)
    }

    private var glyph: some View {
        Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
            .font(.system(size: 42, weight: .bold))
            .foregroundStyle(accent)
            .symbolRenderingMode(.hierarchical)
            .contentTransition(.opacity)
            .shadow(color: accent.opacity(isLocked ? 0.55 : 0.2), radius: 9)
    }

    private var wellColors: [Color] {
        scheme == .dark
            ? [Color(red: 0.035, green: 0.04, blue: 0.055), Color(red: 0.10, green: 0.11, blue: 0.14)]
            : [Color(red: 0.78, green: 0.80, blue: 0.84), Color(red: 0.90, green: 0.91, blue: 0.94)]
    }

    private var capColors: [Color] {
        scheme == .dark
            ? [Color(red: 0.21, green: 0.22, blue: 0.26), Color(red: 0.12, green: 0.13, blue: 0.16)]
            : [Color.white, Color(red: 0.89, green: 0.91, blue: 0.94)]
    }

    private func syncGlow() {
        if isLocked {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
        } else {
            withAnimation(.easeOut(duration: 0.3)) { glow = false }
        }
    }
}

private struct KeycapPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Chrome

/// Keyboard-plate backdrop: solid base, faint dot grid, and an accent wash
/// pooled behind the keycap.
private struct PlateBackground: View {
    @Environment(\.colorScheme) private var scheme
    let isLocked: Bool
    let accent: Color

    var body: some View {
        ZStack {
            base

            DotGrid()
                .foregroundStyle(Color.primary.opacity(scheme == .dark ? 0.055 : 0.07))

            RadialGradient(
                colors: [accent.opacity(washOpacity), .clear],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 10,
                endRadius: 250
            )
        }
    }

    private var base: Color {
        scheme == .dark
            ? Color(red: 0.065, green: 0.07, blue: 0.09)
            : Color(red: 0.94, green: 0.95, blue: 0.97)
    }

    private var washOpacity: Double {
        let dark = scheme == .dark
        if isLocked { return dark ? 0.30 : 0.20 }
        return dark ? 0.15 : 0.11
    }
}

private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 16
            let radius: CGFloat = 1
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .style(.primary))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StatusChip: View {
    let isLocked: Bool
    let accent: Color

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if isLocked {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulse ? 2.4 : 1)
                        .opacity(pulse ? 0 : 0.6)
                }
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
            }

            Text(isLocked ? "LOCKED" : "READY")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .lineLimit(1)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(accent.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
        .onChange(of: isLocked) { locked in
            if locked {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
            } else {
                pulse = false
            }
        }
    }
}

private struct PermissionCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.warn)

                Text("Accessibility access needed")
                    .font(.system(size: 12.5, weight: .semibold))
            }

            Text("macOS requires permission before KeyLock can intercept keys.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Label("Open System Settings", systemImage: "arrow.up.forward.square")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
        .padding(13)
        .background(Palette.warn.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Palette.warn.opacity(0.28), lineWidth: 1)
        )
    }
}
