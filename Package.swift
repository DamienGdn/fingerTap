// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FingerTap",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MultitouchBridge"),
        .target(name: "FingerTapCore"),
        .executableTarget(name: "FingerTap", dependencies: ["FingerTapCore", "MultitouchBridge"]),
        .testTarget(name: "FingerTapCoreTests", dependencies: ["FingerTapCore"]),
    ]
)
