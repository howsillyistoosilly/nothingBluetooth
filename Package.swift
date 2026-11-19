// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CMFControl",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CMFControl", targets: ["CMFControl"])],
    targets: [
        .executableTarget(
            name: "CMFControl",
            path: "Sources/CMFControl",
            resources: [.process("Resources")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
