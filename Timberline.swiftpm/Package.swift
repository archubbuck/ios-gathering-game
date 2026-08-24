// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Timberline",
    platforms: [.iOS("16.0"), .macOS("13.0")],
    products: [
        .iOSApplication(
            name: "Timberline",
            targets: ["AppModule"],
            bundleIdentifier: "com.timberline.app",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [.phone],
            supportedInterfaceOrientations: [
                .portrait,
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "AppModule",
            resources: [
                .process("Assets.xcassets"),
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TimberlineTests",
            dependencies: [],
            path: "Tests"
        )
    ]
)
