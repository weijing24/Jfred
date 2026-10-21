// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Alfred",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Alfred", targets: ["Alfred"])
    ],
    targets: [
        .target(name: "AlfredCore"),
        .executableTarget(
            name: "Alfred",
            dependencies: ["AlfredCore"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("Contacts"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreServices"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("UserNotifications"),
            ]
        ),
        .testTarget(name: "AlfredCoreTests", dependencies: ["AlfredCore"]),
    ]
)
