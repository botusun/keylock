# KeyLock

A lightweight macOS menu-bar utility that blocks all keyboard input with a single click — useful when cleaning your keyboard, letting a pet walk across it, or handing your laptop to someone who should not be typing.

## Features

- One-click keyboard lock / unlock
- Blocks key-down, key-up, modifier keys, and system keys (volume, brightness, media)
- Live status indicator (locked / active)
- Accessibility permission prompt built in
- Minimal 320 × 320 window, stays floating while locked

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (to build from source)
- Accessibility permission (the app will prompt you on first use)

## Installation

### Build from source

```bash
open KeyLock.xcodeproj
```

Select the **KeyLock** scheme, choose your Mac as the target, then press **Cmd + R**.

## Usage

1. Launch KeyLock.
2. If prompted, grant **Accessibility** access in **System Settings → Privacy & Security → Accessibility**.
3. Click **Lock Keyboard** — all key input is blocked system-wide.
4. Click **Unlock Keyboard** (or quit the app) to restore normal input.

> The app window floats above other windows while the keyboard is locked so you can always reach the unlock button with your mouse.

## How it works

KeyLock uses a `CGEvent` tap inserted at the HID layer (`cghidEventTap`, `headInsertEventTap`). When active, the tap intercepts every key-down, key-up, flags-changed, and NX_SYSDEFINED event and discards it before it reaches any application. Removing the tap instantly restores full keyboard access.

Accessibility permission is required because inserting a system-wide event tap is a privileged operation on macOS.

## Project structure

```
KeyLock/
├── KeyLockApp.swift       # App entry point
├── ContentView.swift      # SwiftUI UI
├── KeyboardLocker.swift   # CGEvent tap logic
└── Assets.xcassets/       # App icons
generate_icon.swift        # Icon generation script
```

## License

MIT
