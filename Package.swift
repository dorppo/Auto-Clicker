// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Autoclicker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Autoclicker",
            path: "Sources/Autoclicker"
        ),
    ]
)
