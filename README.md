# Autoclicker

A lightweight macOS menu bar autoclicker. Set an interval, pick a button, set a global hotkey, and let it click. Optional "Humanize" mode adds random jitter to interval, hold duration, and click position so the output doesn't look perfectly metronomic.

No Dock icon, no signed installer, no telemetry — it's a single Swift Package you build locally.

---

## Features

- **Menu bar only** — no Dock icon, no clutter. Lives as a status item with a cursor symbol.
- **Configurable interval** — any value in milliseconds, seconds, or minutes.
- **Any mouse button** — left, right, or middle.
- **Click location** — follow the cursor, or click a fixed screen point.
  - Pick the fixed point with a 3-second overlay countdown, or capture the current cursor position instantly.
- **Global hotkey** — start/stop from anywhere. Default `⌃⌥⌘A`. Re-bindable from the Settings window.
- **Click limit** — optional automatic stop after N clicks.
- **Humanize mode** — randomize:
  - **Interval jitter** (±0–50%)
  - **Hold duration** (0–300 ms mouse-down before mouse-up)
  - **Hold jitter** (±0–50%)
  - **Position jitter** (0–20 px radius around the target)
- **Persistent settings** — every option is stored in `UserDefaults` and restored on launch.

---

## Requirements

- **macOS 13 (Ventura) or later**
- **Xcode command-line tools** (for `swift build`) — install with `xcode-select --install`
- **Accessibility permission** — granted on first launch (see below)

---

## Install / Build

Clone and build the `.app` bundle:

```sh
git clone https://github.com/dorppo/Auto-Clicker.git
cd Auto-Clicker
make app
```

This produces `Autoclicker.app` in the project directory, ad-hoc codesigned so macOS will run it locally.

Then either double-click the app in Finder, or:

```sh
make run        # build + open
```

Other targets:

```sh
make dev        # swift run (debug, no .app bundle, runs in foreground)
make build      # release build only, no .app bundle
make clean      # remove .build/ and Autoclicker.app
```

> **Tip:** if Finder refuses to open the app with "cannot be verified," strip the quarantine attribute:
> `xattr -dr com.apple.quarantine Autoclicker.app`

---

## First launch

1. Run the app. **There is no Dock icon and no window.** Look for a small cursor icon (`cursorarrow.click`) in the right side of your menu bar.
2. macOS will prompt for **Accessibility** permission. The app needs this to synthesize mouse events. If you miss the prompt, open **System Settings → Privacy & Security → Accessibility** and toggle Autoclicker on. The Settings window has an "Open Accessibility Settings…" shortcut.
3. Click the menu bar icon → **Settings…** to configure.

When the clicker is running, the menu bar icon switches to `cursorarrow.click.2` so you can see the state at a glance.

---

## Usage

### From the menu bar
- **Start / Stop** — toggle the clicker. The current hotkey is shown alongside.
- **Settings…** — open the configuration window (`⌘,`).
- **Quit Autoclicker** — `⌘Q`.

### From the Settings window
- **Interval** — number + unit (ms / s / min). Live "≈ N / sec" or "/ min" rate is shown.
- **Mouse Button** — Left / Right / Middle.
- **Click Location**
  - *At cursor* — every click happens wherever the cursor is at that moment.
  - *Fixed point* — click a stored screen coordinate. Use **Pick…** to capture via a 3-second overlay, or **Use Current** to snapshot the cursor's current position.
- **Humanize** — toggle on to randomize timing and position (see below).
- **Stop after N clicks** — optional click limit.
- **Start/Stop Hotkey** — click the recorder field, then press your desired combo. At least one modifier (⌃ ⌥ ⇧ ⌘) recommended to avoid intercepting normal typing.

### From the global hotkey
- Press it from anywhere to toggle. Default: **⌃⌥⌘A**.

---

## Humanize mode

When enabled, every click is independently randomized:

| Knob | Range | Meaning |
| --- | --- | --- |
| Interval jitter | ±0–50% | Each gap is `interval ± random(jitter%)`. |
| Hold duration | 0–300 ms | Time between mouse-down and mouse-up. |
| Hold jitter | ±0–50% | Each hold is `holdDuration ± random(jitter%)`. |
| Position jitter | 0–20 px | Click lands uniformly inside a disc of this radius around the target. |

The Settings window shows the resulting min–max for interval and hold so you can dial in the variance you want.

---

## Permissions, in detail

The clicker uses `CGEvent.post(tap:)` against `cghidEventTap`, which on macOS requires the calling process to be a **trusted accessibility client**. There's no way around this — every macOS automation tool that synthesizes input needs it.

If the app appears to do nothing when you start it:
1. Open **System Settings → Privacy & Security → Accessibility**.
2. Make sure **Autoclicker** is in the list and toggled **on**.
3. Quit (`⌘Q`) and re-launch the app — macOS sometimes caches the old state until restart.

---

## Troubleshooting

**"I can't see the menu bar icon."**
On laptops with a notch, the icon may be clipped if you have many menu bar items. Try Bartender / Hidden Bar, or temporarily quit other status-bar apps.

**"Clicks fire but at the wrong place on a multi-monitor setup."**
Coordinates are stored relative to the *primary* display. If you change your primary display, re-pick the fixed point.

**"The hotkey doesn't trigger."**
A few possible causes:
- Another app has registered the same combo. Try a different combination.
- Some single-key bindings (e.g. just `F12`) get intercepted by Mission Control / brightness keys. Add a modifier.
- Accessibility permission is required for the global hotkey too. See above.

**"The app crashes / doesn't launch."**
Check Console.app, or stream live logs:
```sh
log stream --predicate 'process == "Autoclicker"'
```

---

## Project layout

```
Sources/Autoclicker/
  main.swift              # NSApplication bootstrap (accessory mode)
  AppDelegate.swift       # status item, menu, settings window wiring
  ClickerEngine.swift     # click scheduling, posting CGEvents, jitter
  Settings.swift          # ObservableObject persisted via UserDefaults
  SettingsView.swift      # SwiftUI configuration UI
  Hotkey.swift            # Hotkey struct, key-code → display name
  HotkeyMonitor.swift     # global hotkey listener
  HotkeyRecorderView.swift # SwiftUI recorder field
  CaptureOverlay.swift    # 3-second countdown HUD for fixed-point capture
  Permissions.swift       # AXIsProcessTrustedWithOptions wrapper
Info.plist                # bundle metadata, LSUIElement = true
Package.swift             # SwiftPM manifest (executableTarget)
Makefile                  # build / app / run / dev / clean
```

---

## Use responsibly

This tool synthesizes real mouse input at the system level. **Do not** use it to violate the terms of service of any game, website, or other software. I am not responsible for accounts banned, work lost, or other consequences of misuse.
