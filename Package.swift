// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Maccopy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Maccopy",
            path: "Sources/Maccopy",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
