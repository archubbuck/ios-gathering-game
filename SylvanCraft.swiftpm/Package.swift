// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "SylvanCraft",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "SylvanCraft",
            targets: ["AppModule"],
            bundleIdentifier: "com.adamchubbuck.sylvancraft",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [.phone],
            supportedInterfaceOrientations: [.portrait]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "AppModule",
            resources: [.process("Assets.xcassets")]
        )
    ]
)
