// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenMouseSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ScreenMouseSwitcher",
            path: "Sources/ScreenMouseSwitcher"
        )
    ]
)
