import AppKit

final class ClickerEngine {
    private var pendingItem: DispatchWorkItem?
    private var clickCount = 0

    private(set) var isRunning = false
    var onStateChange: ((Bool) -> Void)?
    var onTick: ((Int) -> Void)?

    private unowned let settings: Settings

    init(settings: Settings) {
        self.settings = settings
    }

    func toggle() { isRunning ? stop() : start() }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        clickCount = 0
        onStateChange?(true)
        scheduleNext(after: 0)
    }

    func stop() {
        guard isRunning else { return }
        pendingItem?.cancel()
        pendingItem = nil
        isRunning = false
        onStateChange?(false)
    }

    // MARK: Scheduling

    private func scheduleNext(after delay: TimeInterval) {
        let item = DispatchWorkItem { [weak self] in self?.performClick() }
        pendingItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func performClick() {
        guard isRunning else { return }
        let point = clickPoint()
        postEvent(down: true, at: point)

        let hold = nextHoldSeconds()
        let release = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.postEvent(down: false, at: point)
            self.clickCount += 1
            self.onTick?(self.clickCount)
            if self.settings.limitEnabled && self.clickCount >= self.settings.limitClicks {
                self.stop()
                return
            }
            self.scheduleNext(after: self.nextIntervalSeconds())
        }
        pendingItem = release
        DispatchQueue.main.asyncAfter(deadline: .now() + hold, execute: release)
    }

    // MARK: Randomization

    private func nextIntervalSeconds() -> TimeInterval {
        let base = settings.intervalSeconds
        guard settings.humanizeEnabled, settings.intervalJitterPercent > 0 else { return base }
        let jitter = base * (settings.intervalJitterPercent / 100)
        return max(0.001, base + Double.random(in: -jitter...jitter))
    }

    private func nextHoldSeconds() -> TimeInterval {
        guard settings.humanizeEnabled else { return 0 }
        let baseMs = max(0, settings.holdDurationMs)
        let jitterMs = baseMs * (settings.holdJitterPercent / 100)
        return max(0, (baseMs + Double.random(in: -jitterMs...jitterMs)) / 1000.0)
    }

    private func clickPoint() -> CGPoint {
        let base: CGPoint
        switch settings.location {
        case .cursor: base = MouseGeometry.cgPointFromCursor()
        case .fixed:  base = settings.fixedPoint
        }
        guard settings.humanizeEnabled, settings.positionJitterPx > 0 else { return base }
        // Uniform inside a disc of the given pixel radius.
        let r = settings.positionJitterPx
        let theta = Double.random(in: 0..<2 * .pi)
        let radius = sqrt(Double.random(in: 0...1)) * r
        return CGPoint(x: base.x + cos(theta) * radius, y: base.y + sin(theta) * radius)
    }

    // MARK: Posting

    private func postEvent(down: Bool, at point: CGPoint) {
        let (type, btn): (CGEventType, CGMouseButton) = {
            switch settings.button {
            case .left:   return (down ? .leftMouseDown  : .leftMouseUp,  .left)
            case .right:  return (down ? .rightMouseDown : .rightMouseUp, .right)
            case .middle: return (down ? .otherMouseDown : .otherMouseUp, .center)
            }
        }()
        if let e = CGEvent(mouseEventSource: nil, mouseType: type,
                           mouseCursorPosition: point, mouseButton: btn) {
            e.post(tap: .cghidEventTap)
        }
    }
}

enum MouseGeometry {
    /// NSEvent.mouseLocation (origin bottom-left of primary screen)
    /// → CGEvent global coordinates (origin top-left of primary screen).
    static func cgPointFromCursor() -> CGPoint {
        let pos = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: pos.x, y: primaryHeight - pos.y)
    }

    static func cgPoint(fromScreenPoint p: NSPoint) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: primaryHeight - p.y)
    }

    static func screenPoint(fromCG p: CGPoint) -> NSPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSPoint(x: p.x, y: primaryHeight - p.y)
    }
}
