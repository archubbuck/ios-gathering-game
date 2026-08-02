// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Timberline",
    platforms: [.iOS("16.0")],
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
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [
                .portrait,
                .portraitUpsideDown(.when(deviceFamilies: [.pad])),
                .landscapeLeft(.when(deviceFamilies: [.pad])),
                .landscapeRight(.when(deviceFamilies: [.pad])),
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
        )
    ]
)
