import Foundation
import AppKit

final class Settings: ObservableObject {
    enum MouseButton: Int, CaseIterable, Identifiable, Codable {
        case left = 0, right = 1, middle = 2
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .left: return "Left"
            case .right: return "Right"
            case .middle: return "Middle"
            }
        }
    }

    enum Location: Int, CaseIterable, Identifiable, Codable {
        case cursor = 0, fixed = 1
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .cursor: return "At cursor"
            case .fixed: return "Fixed point"
            }
        }
    }

    enum IntervalUnit: String, CaseIterable, Identifiable, Codable {
        case milliseconds = "ms"
        case seconds = "s"
        case minutes = "min"
        var id: String { rawValue }
        var seconds: Double {
            switch self {
            case .milliseconds: return 0.001
            case .seconds: return 1
            case .minutes: return 60
            }
        }
    }

    @Published var intervalAmount: Double { didSet { save() } }
    @Published var intervalUnit: IntervalUnit { didSet { save() } }
    @Published var button: MouseButton { didSet { save() } }
    @Published var location: Location { didSet { save() } }
    @Published var fixedPoint: CGPoint { didSet { save() } }
    @Published var limitEnabled: Bool { didSet { save() } }
    @Published var limitClicks: Int { didSet { save() } }
    @Published var hotkey: Hotkey { didSet { save() } }

    @Published var humanizeEnabled: Bool { didSet { save() } }
    @Published var intervalJitterPercent: Double { didSet { save() } }   // 0...100, applied as ±% of interval
    @Published var holdDurationMs: Double { didSet { save() } }          // base mouse-down → mouse-up time
    @Published var holdJitterPercent: Double { didSet { save() } }       // ±% of hold duration
    @Published var positionJitterPx: Double { didSet { save() } }        // radius of disc around target

    var intervalSeconds: TimeInterval {
        max(0.001, intervalAmount * intervalUnit.seconds)
    }

    var clicksPerSecond: Double {
        1.0 / intervalSeconds
    }

    init() {
        let d = UserDefaults.standard
        self.intervalAmount = d.object(forKey: "intervalAmount") as? Double ?? 100
        self.intervalUnit = IntervalUnit(rawValue: d.string(forKey: "intervalUnit") ?? "") ?? .milliseconds
        self.button = MouseButton(rawValue: d.integer(forKey: "button")) ?? .left
        self.location = Location(rawValue: d.integer(forKey: "location")) ?? .cursor
        let fx = d.double(forKey: "fixedX")
        let fy = d.double(forKey: "fixedY")
        self.fixedPoint = CGPoint(x: fx, y: fy)
        self.limitEnabled = d.bool(forKey: "limitEnabled")
        self.limitClicks = (d.object(forKey: "limitClicks") as? Int) ?? 100
        if let data = d.data(forKey: "hotkey"),
           let hk = try? JSONDecoder().decode(Hotkey.self, from: data) {
            self.hotkey = hk
        } else {
            self.hotkey = .default
        }

        self.humanizeEnabled = d.bool(forKey: "humanizeEnabled")
        self.intervalJitterPercent = (d.object(forKey: "intervalJitterPercent") as? Double) ?? 20
        self.holdDurationMs = (d.object(forKey: "holdDurationMs") as? Double) ?? 50
        self.holdJitterPercent = (d.object(forKey: "holdJitterPercent") as? Double) ?? 20
        self.positionJitterPx = (d.object(forKey: "positionJitterPx") as? Double) ?? 3
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(intervalAmount, forKey: "intervalAmount")
        d.set(intervalUnit.rawValue, forKey: "intervalUnit")
        d.set(button.rawValue, forKey: "button")
        d.set(location.rawValue, forKey: "location")
        d.set(Double(fixedPoint.x), forKey: "fixedX")
        d.set(Double(fixedPoint.y), forKey: "fixedY")
        d.set(limitEnabled, forKey: "limitEnabled")
        d.set(limitClicks, forKey: "limitClicks")
        if let data = try? JSONEncoder().encode(hotkey) {
            d.set(data, forKey: "hotkey")
        }
        d.set(humanizeEnabled, forKey: "humanizeEnabled")
        d.set(intervalJitterPercent, forKey: "intervalJitterPercent")
        d.set(holdDurationMs, forKey: "holdDurationMs")
        d.set(holdJitterPercent, forKey: "holdJitterPercent")
        d.set(positionJitterPx, forKey: "positionJitterPx")
    }
}
