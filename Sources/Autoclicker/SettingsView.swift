import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var state: AppState
    let toggle: () -> Void
    let pickFixedPoint: () -> Void
    let useCurrentCursor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if !state.accessibilityGranted {
                permissionBanner
            }
            Divider()
            intervalSection
            buttonSection
            locationSection
            humanizeSection
            limitSection
            hotkeySection
            Divider()
            footer
        }
        .padding(20)
        .frame(width: 380)
    }

    private var header: some View {
        HStack {
            Text("Autoclicker")
                .font(.title2.bold())
            Spacer()
            Button(action: toggle) {
                Text(state.isRunning ? "Stop" : "Start")
                    .frame(width: 64)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .tint(state.isRunning ? .red : .accentColor)
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility permission required")
                    .font(.body.weight(.semibold))
                Text("Without it, clicks won't fire and the global hotkey won't trigger. Grant access, then come back — no relaunch needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings…") {
                    Permissions.openAccessibilitySettings()
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Interval").font(.headline)
            HStack {
                TextField("",
                          value: $settings.intervalAmount,
                          formatter: Self.numberFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Picker("", selection: $settings.intervalUnit) {
                    ForEach(Settings.IntervalUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
                Spacer()
                Text(rateDescription)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }

    private var rateDescription: String {
        let cps = settings.clicksPerSecond
        if cps >= 1 {
            return String(format: "≈ %.1f / sec", cps)
        } else {
            let cpm = cps * 60
            if cpm >= 1 { return String(format: "≈ %.1f / min", cpm) }
            return String(format: "≈ %.2f / min", cpm)
        }
    }

    private var buttonSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mouse Button").font(.headline)
            Picker("", selection: $settings.button) {
                ForEach(Settings.MouseButton.allCases) { b in
                    Text(b.label).tag(b)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Click Location").font(.headline)
            Picker("", selection: $settings.location) {
                ForEach(Settings.Location.allCases) { l in
                    Text(l.label).tag(l)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if settings.location == .fixed {
                let display = MouseGeometry.screenPoint(fromCG: settings.fixedPoint)
                HStack(spacing: 8) {
                    Text(String(format: "X: %.0f", display.x))
                        .monospacedDigit()
                    Text(String(format: "Y: %.0f", display.y))
                        .monospacedDigit()
                    Spacer()
                    Button("Use Current", action: useCurrentCursor)
                    Button("Pick…", action: pickFixedPoint)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
    }

    private var humanizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Humanize", isOn: $settings.humanizeEnabled)
                .toggleStyle(.switch)
                .font(.headline)

            if settings.humanizeEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    humanizeRow(
                        label: "Interval jitter",
                        valueText: String(format: "±%.0f%%", settings.intervalJitterPercent),
                        slider: Slider(value: $settings.intervalJitterPercent, in: 0...50, step: 1),
                        detail: intervalJitterDetail
                    )
                    humanizeRow(
                        label: "Hold duration",
                        valueText: String(format: "%.0f ms", settings.holdDurationMs),
                        slider: Slider(value: $settings.holdDurationMs, in: 0...300, step: 5),
                        detail: nil
                    )
                    humanizeRow(
                        label: "Hold jitter",
                        valueText: String(format: "±%.0f%%", settings.holdJitterPercent),
                        slider: Slider(value: $settings.holdJitterPercent, in: 0...50, step: 1),
                        detail: holdJitterDetail
                    )
                    humanizeRow(
                        label: "Position jitter",
                        valueText: String(format: "%.0f px", settings.positionJitterPx),
                        slider: Slider(value: $settings.positionJitterPx, in: 0...20, step: 1),
                        detail: settings.positionJitterPx > 0 ? "Click lands within this radius of the target" : nil
                    )
                }
                .padding(.leading, 4)
            }
        }
    }

    private func humanizeRow<S: View>(label: String, valueText: String, slider: S, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).frame(width: 110, alignment: .leading)
                slider
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 110)
            }
        }
    }

    private var intervalJitterDetail: String? {
        guard settings.intervalJitterPercent > 0 else { return nil }
        let baseMs = settings.intervalSeconds * 1000
        let jitter = baseMs * settings.intervalJitterPercent / 100
        return String(format: "%.0f–%.0f ms between clicks", baseMs - jitter, baseMs + jitter)
    }

    private var holdJitterDetail: String? {
        guard settings.holdJitterPercent > 0, settings.holdDurationMs > 0 else { return nil }
        let jitter = settings.holdDurationMs * settings.holdJitterPercent / 100
        return String(format: "%.0f–%.0f ms hold", settings.holdDurationMs - jitter, settings.holdDurationMs + jitter)
    }

    private var limitSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Stop after a number of clicks", isOn: $settings.limitEnabled)
                .toggleStyle(.checkbox)
            if settings.limitEnabled {
                HStack {
                    Text("Limit:")
                    TextField("",
                              value: $settings.limitClicks,
                              formatter: Self.intFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("clicks").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Start/Stop Hotkey").font(.headline)
            HStack {
                HotkeyRecorderView(hotkey: $settings.hotkey)
                    .frame(height: 28)
                Text("Click then press combo")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Spacer()
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Open Accessibility Settings…") {
                Permissions.openAccessibilitySettings()
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .font(.callout)
    }

    static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimum = 1
        f.maximumFractionDigits = 3
        f.allowsFloats = true
        return f
    }()

    static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = 1
        f.maximum = 1_000_000
        f.allowsFloats = false
        return f
    }()
}
