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
            FocusBackground(isLocked: locker.isLocked, accentColor: accentColor)

            VStack(spacing: 0) {
                header

                Spacer(minLength: 26)

                LockOrb(isLocked: locker.isLocked, accentColor: accentColor) {
                    locker.toggleLock()
                }
                .accessibilityLabel(locker.isLocked ? "Unlock keyboard" : "Lock keyboard")
                .accessibilityHint(locker.isLocked ? "Restores keyboard input" : "Blocks keyboard input")

                Spacer(minLength: 22)

                VStack(spacing: 6) {
                    Text(locker.isLocked ? "Keyboard Locked" : "Keyboard Ready")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.interpolate)

                    Text(locker.isLocked ? "Tap the dial to restore input" : "Tap the dial to block input")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                if !locker.hasAccessibilityPermission {
                    PermissionCallout(action: locker.openAccessibilitySettings)
                        .padding(.top, 22)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: locker.isLocked)
        .animation(.easeInOut(duration: 0.25), value: locker.hasAccessibilityPermission)
        .background(WindowAccessor(locker: locker))
    }

    private var accentColor: Color {
        locker.isLocked
            ? Color(red: 0.17, green: 0.66, blue: 0.45)
            : Color(red: 0.97, green: 0.47, blue: 0.16)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentColor)

            Text("KeyLock")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            StatusPill(isLocked: locker.isLocked, tint: accentColor)
        }
    }
}

#Preview {
    ContentView(locker: KeyboardLocker())
}

// MARK: - Lock Orb

private struct LockOrb: View {
    @Environment(\.colorScheme) private var colorScheme
    let isLocked: Bool
    let accentColor: Color
    let action: () -> Void

    @State private var breathe = false

    private let disc: CGFloat = 132      // inner sphere
    private let ringInset: CGFloat = 14  // accent ring sits outside the disc
    private var ringSize: CGFloat { disc + ringInset * 2 }
    private var tickRadius: CGFloat { ringSize / 2 + 15 }
    private var canvas: CGFloat { (tickRadius + 8) * 2 }

    var body: some View {
        Button(action: action) {
            ZStack {
                halo
                tickGauge
                trackRing
                accentArc
                sphere
                glyph
            }
            .frame(width: canvas, height: canvas)
            .contentShape(Circle())
        }
        .buttonStyle(OrbButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    // Soft colored glow behind the dial — breathes gently, stronger when locked.
    private var halo: some View {
        Circle()
            .fill(accentColor)
            .frame(width: disc, height: disc)
            .opacity(isLocked ? (breathe ? 0.40 : 0.26) : (breathe ? 0.22 : 0.14))
            .blur(radius: 28)
            .scaleEffect(breathe ? 1.08 : 0.94)
    }

    // Precision-gauge tick ring — minor + major ticks that tint accent when locked.
    private var tickGauge: some View {
        ZStack {
            ForEach(0..<60, id: \.self) { i in
                let major = i % 5 == 0
                Capsule()
                    .fill(tickColor(major: major))
                    .frame(width: major ? 2.4 : 1.6, height: major ? 9 : 5)
                    .offset(y: -tickRadius)
                    .rotationEffect(.degrees(Double(i) / 60 * 360))
            }
        }
    }

    private var trackRing: some View {
        Circle()
            .stroke(accentColor.opacity(colorScheme == .dark ? 0.16 : 0.14), lineWidth: 9)
            .frame(width: ringSize, height: ringSize)
    }

    // Accent progress arc with an angular-gradient sweep and a glow.
    private var accentArc: some View {
        Circle()
            .trim(from: 0, to: isLocked ? 1 : 0.16)
            .stroke(
                AngularGradient(
                    colors: [accentColor.opacity(0.55), accentColor, accentColor.opacity(0.9)],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                style: StrokeStyle(lineWidth: 9, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: ringSize, height: ringSize)
            .shadow(color: accentColor.opacity(0.45), radius: 7)
    }

    // Glossy spherical disc: gradient body + top specular + faked inner shadow + rim.
    private var sphere: some View {
        Circle()
            .fill(
                LinearGradient(colors: discColors, startPoint: .top, endPoint: .bottom)
            )
            .frame(width: disc, height: disc)
            .overlay(specular)
            .overlay(innerShadow)
            .overlay(
                Circle().strokeBorder(.white.opacity(colorScheme == .dark ? 0.12 : 0.7), lineWidth: 1)
            )
            .clipShape(Circle())
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.16), radius: 14, y: 7)
    }

    private var specular: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(colorScheme == .dark ? 0.20 : 0.85), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: disc * 0.74, height: disc * 0.5)
            .offset(y: -disc * 0.22)
            .blur(radius: 3)
            .allowsHitTesting(false)
    }

    private var innerShadow: some View {
        Circle()
            .stroke(Color.black.opacity(colorScheme == .dark ? 0.5 : 0.16), lineWidth: 9)
            .blur(radius: 6)
            .offset(y: 2)
            .mask(Circle())
            .allowsHitTesting(false)
    }

    private var glyph: some View {
        Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(accentColor)
            .symbolRenderingMode(.hierarchical)
            .contentTransition(.opacity)
            .shadow(color: accentColor.opacity(0.25), radius: 6)
    }

    private func tickColor(major: Bool) -> Color {
        if isLocked {
            return accentColor.opacity(major ? 0.85 : 0.45)
        }
        return Color.primary.opacity(major ? 0.30 : 0.15)
    }

    private var discColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.20, green: 0.21, blue: 0.23), Color(red: 0.11, green: 0.12, blue: 0.13)]
        }
        return [Color.white, Color(red: 0.92, green: 0.94, blue: 0.96)]
    }
}

private struct OrbButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Chrome

private struct FocusBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let isLocked: Bool
    let accentColor: Color

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            // Top-down sheen for subtle vertical depth.
            LinearGradient(
                colors: [.white.opacity(colorScheme == .dark ? 0.04 : 0.5), .clear],
                startPoint: .top,
                endPoint: .center
            )

            // Accent glow pooled behind the orb.
            RadialGradient(
                colors: [
                    accentColor.opacity(glowOpacity),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 8,
                endRadius: 260
            )
        }
    }

    private var glowOpacity: Double {
        let dark = colorScheme == .dark
        if isLocked { return dark ? 0.26 : 0.18 }
        return dark ? 0.16 : 0.11
    }
}

private struct StatusPill: View {
    let isLocked: Bool
    let tint: Color

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if isLocked {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulse ? 2.2 : 1)
                        .opacity(pulse ? 0 : 0.6)
                }
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
            }

            Text(isLocked ? "Locked" : "Ready")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
        .onChange(of: isLocked) { locked in
            if locked {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
            } else {
                pulse = false
            }
        }
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
