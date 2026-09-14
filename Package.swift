// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SourceSwitch",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "SourceSwitch",
            path: "Sources/SourceSwitch",
            swiftSettings: [.defaultIsolation(MainActor.self)],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "SourceSwitchTests",
            dependencies: ["SourceSwitch"],
            path: "Tests/SourceSwitchTests",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
