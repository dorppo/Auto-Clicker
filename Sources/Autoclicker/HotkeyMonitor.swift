import AppKit

final class HotkeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    var hotkey: Hotkey
    var onTrigger: (() -> Void)?

    init(hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    func start() {
        stop()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if self.hotkey.matches(event) {
                DispatchQueue.main.async { self.onTrigger?() }
            }
        }
        // Local monitor so the hotkey also works when our settings window has focus.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.hotkey.matches(event) {
                DispatchQueue.main.async { self.onTrigger?() }
                return nil
            }
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    func update(hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
