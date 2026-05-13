// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClipboardManager",
            path: "Sources/ClipboardManager",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
