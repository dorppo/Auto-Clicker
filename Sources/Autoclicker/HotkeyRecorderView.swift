import SwiftUI
import AppKit

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: Hotkey

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> RecorderButton {
        let view = RecorderButton()
        view.coordinator = context.coordinator
        view.refresh(with: hotkey)
        return view
    }

    func updateNSView(_ view: RecorderButton, context: Context) {
        if !view.isRecording {
            view.refresh(with: hotkey)
        }
    }

    final class Coordinator {
        var parent: HotkeyRecorderView
        init(_ parent: HotkeyRecorderView) { self.parent = parent }
        func update(_ hk: Hotkey) { parent.hotkey = hk }
    }
}

final class RecorderButton: NSButton {
    var coordinator: HotkeyRecorderView.Coordinator?
    private(set) var isRecording = false
    private var monitor: Any?

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func refresh(with hotkey: Hotkey) {
        title = hotkey.displayString.isEmpty ? "Click to set…" : hotkey.displayString
    }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        title = "Press keys…"
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                // Escape (53) cancels; require at least one modifier.
                if event.keyCode == 53 && mods.isEmpty {
                    self.stopRecording()
                    return nil
                }
                guard !mods.isEmpty else {
                    NSSound.beep()
                    return nil
                }
                let hk = Hotkey(keyCode: event.keyCode, modifierFlags: mods.rawValue)
                self.coordinator?.update(hk)
                self.stopRecording()
                self.refresh(with: hk)
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        isRecording = false
    }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}
