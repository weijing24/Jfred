// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jfred",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Jfred", targets: ["Jfred"])
    ],
    targets: [
        .target(
            name: "JfredCore",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
        .executableTarget(
            name: "Jfred",
            dependencies: ["JfredCore"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library", "-warnings-as-errors"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreServices"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .testTarget(
            name: "JfredCoreTests",
            dependencies: ["JfredCore"],
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"])
            ]
        ),
    ]
)
