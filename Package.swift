// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jumpo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Jumpo", targets: ["Jumpo"])],
    targets: [
        .target(name: "JumpoCore"),
        .executableTarget(name: "Jumpo", dependencies: ["JumpoCore"]),
        .testTarget(name: "JumpoCoreTests", dependencies: ["JumpoCore"])
    ]
)
