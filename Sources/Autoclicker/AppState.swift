import Foundation

final class AppState: ObservableObject {
    @Published var accessibilityGranted: Bool = false
    @Published var isRunning: Bool = false
    @Published var clickCount: Int = 0
}
