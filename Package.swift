// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jlfred",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Jlfred", targets: ["Jlfred"])
    ],
    targets: [
        .target(name: "JlfredCore"),
        .executableTarget(
            name: "Jlfred",
            dependencies: ["JlfredCore"],
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
        .testTarget(name: "JlfredCoreTests", dependencies: ["JlfredCore"]),
    ]
)
