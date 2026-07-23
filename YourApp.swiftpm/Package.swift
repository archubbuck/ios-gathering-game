// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "iOSFullStackStarter",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "iOSFullStackStarter",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.iosfullstackstarter",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            // Set your app icon and accent color in Swift Playgrounds Project
            // Settings — it will edit this file for you.
            appIcon: .placeholder(icon: .cat),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown,
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "AppModule"
        )
    ]
)
