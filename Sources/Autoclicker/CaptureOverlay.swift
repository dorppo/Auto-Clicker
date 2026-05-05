import AppKit

final class CaptureOverlay {
    private var window: NSWindow?
    private var label: NSTextField?
    private var timer: Timer?
    private var remaining: Int = 0
    private var onComplete: ((CGPoint) -> Void)?

    func start(seconds: Int, onComplete: @escaping (CGPoint) -> Void) {
        cancel()
        self.remaining = seconds
        self.onComplete = onComplete

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let size = NSSize(width: 380, height: 80)
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height - 60,
            width: size.width,
            height: size.height
        )

        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .statusBar
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 14
        bg.autoresizingMask = [.width, .height]

        let text = NSTextField(labelWithString: "")
        text.alignment = .center
        text.font = .systemFont(ofSize: 18, weight: .semibold)
        text.textColor = .labelColor
        text.frame = NSRect(x: 12, y: 18, width: size.width - 24, height: 44)
        bg.addSubview(text)

        win.contentView = bg
        win.orderFrontRegardless()

        self.window = win
        self.label = text
        update()

        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
        window = nil
        label = nil
        onComplete = nil
    }

    private func tick() {
        remaining -= 1
        if remaining <= 0 {
            let cg = MouseGeometry.cgPointFromCursor()
            let cb = onComplete
            cancel()
            cb?(cg)
        } else {
            update()
        }
    }

    private func update() {
        label?.stringValue = "Move cursor to target — capturing in \(remaining)…"
    }
}
