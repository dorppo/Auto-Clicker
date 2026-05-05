import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let appState = AppState()
    private lazy var engine = ClickerEngine(settings: settings)
    private lazy var hotkey = HotkeyMonitor(hotkey: settings.hotkey)
    private let overlay = CaptureOverlay()

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    private var settingsCancellable: Any?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Permissions.checkAccessibility(prompt: true)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        rebuildMenu()

        engine.onStateChange = { [weak self] running in
            self?.appState.isRunning = running
            self?.updateStatusIcon()
            self?.rebuildMenu()
        }
        engine.onTick = { [weak self] count in
            self?.appState.clickCount = count
        }

        hotkey.onTrigger = { [weak self] in self?.engine.toggle() }
        hotkey.start()

        settingsCancellable = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.hotkey.hotkey != self.settings.hotkey {
                    self.hotkey.update(hotkey: self.settings.hotkey)
                    // Re-attach the global tap so the new combo takes effect immediately.
                    self.hotkey.start()
                }
                self.rebuildMenu()
            }
        }

        startPermissionPolling()
    }

    // MARK: Accessibility polling

    private func startPermissionPolling() {
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
        refreshPermission()
    }

    private func refreshPermission() {
        let trusted = Permissions.checkAccessibility(prompt: false)
        let was = appState.accessibilityGranted
        if trusted != was {
            appState.accessibilityGranted = trusted
            if trusted {
                // Permission newly granted — reattach the global event monitor so it
                // actually receives keystrokes (it silently no-ops without permission).
                hotkey.start()
            }
            updateStatusIcon()
            rebuildMenu()
        }
    }

    // MARK: Menu / status item

    private func updateStatusIcon() {
        let symbol: String
        if !appState.accessibilityGranted {
            symbol = "exclamationmark.triangle"
        } else if engine.isRunning {
            symbol = "cursorarrow.click.2"
        } else {
            symbol = "cursorarrow.click"
        }
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Autoclicker")
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if !appState.accessibilityGranted {
            let warn = NSMenuItem(title: "⚠︎ Accessibility permission needed", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            let open = NSMenuItem(title: "Open Accessibility Settings…",
                                  action: #selector(openAccessibilityAction),
                                  keyEquivalent: "")
            open.target = self
            menu.addItem(open)
            menu.addItem(.separator())
        }

        let toggle = NSMenuItem(
            title: engine.isRunning ? "Stop" : "Start",
            action: #selector(toggleAction),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.attributedTitle = makeMenuTitle(
            primary: engine.isRunning ? "Stop" : "Start",
            secondary: settings.hotkey.displayString
        )
        menu.addItem(toggle)

        menu.addItem(.separator())

        let info = NSMenuItem(title: settingsSummary(), action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        menu.addItem(.separator())

        let prefs = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        let quit = NSMenuItem(
            title: "Quit Autoclicker",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func makeMenuTitle(primary: String, secondary: String) -> NSAttributedString {
        let s = NSMutableAttributedString(string: primary, attributes: [
            .font: NSFont.menuFont(ofSize: 0)
        ])
        if !secondary.isEmpty {
            s.append(NSAttributedString(string: "    " + secondary, attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.secondaryLabelColor
            ]))
        }
        return s
    }

    private func settingsSummary() -> String {
        let amount: String = {
            if settings.intervalAmount == settings.intervalAmount.rounded() {
                return String(Int(settings.intervalAmount))
            } else {
                return String(format: "%.2f", settings.intervalAmount)
            }
        }()
        let loc: String = {
            switch settings.location {
            case .cursor: return "at cursor"
            case .fixed:
                let p = MouseGeometry.screenPoint(fromCG: settings.fixedPoint)
                return String(format: "at %.0f, %.0f", p.x, p.y)
            }
        }()
        return "\(amount) \(settings.intervalUnit.rawValue) • \(settings.button.label) • \(loc)"
    }

    // MARK: Actions

    @objc private func toggleAction() {
        engine.toggle()
    }

    @objc private func openAccessibilityAction() {
        Permissions.openAccessibilitySettings()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settings,
                state: appState,
                toggle: { [weak self] in self?.engine.toggle() },
                pickFixedPoint: { [weak self] in self?.beginPickLocation() },
                useCurrentCursor: { [weak self] in self?.useCurrentCursor() }
            )
            let host = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: host)
            win.title = "Autoclicker"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.center()
            settingsWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func beginPickLocation() {
        settings.location = .fixed
        settingsWindow?.orderOut(nil)
        overlay.start(seconds: 3) { [weak self] cgPoint in
            guard let self else { return }
            self.settings.fixedPoint = cgPoint
            self.openSettings()
        }
    }

    private func useCurrentCursor() {
        settings.location = .fixed
        settings.fixedPoint = MouseGeometry.cgPointFromCursor()
    }
}
