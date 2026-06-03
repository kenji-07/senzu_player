// swift-tools-version: 5.9
// Flutter iOS plugin — Swift Package Manager manifest
// See: https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors

import PackageDescription

let package = Package(
    name: "senzu_player",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "senzu-player", targets: ["senzu_player"]),
    ],
    dependencies: [
        // FlutterFramework dependency (required by Flutter tooling)
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Google Cast SDK wrapper maintained by SRGSSR
        .package(url: "https://github.com/SRGSSR/google-cast-sdk.git", from: "4.8.4"),
        // ScreenProtectorKit for preventing screenshots and recording detection
        .package(url: "https://github.com/prongbang/ScreenProtectorKit.git", from: "1.5.1")
    ],
    targets: [
        .target(
            name: "senzu_player",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "GoogleCast", package: "google-cast-sdk"),
                .product(name: "ScreenProtectorKit", package: "ScreenProtectorKit"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("MediaPlayer"),
                .linkedFramework("UIKit"),
                .linkedFramework("Network"),
                .linkedFramework("VideoToolbox"),
            ]
        ),
    ]
)