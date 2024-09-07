// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyNodeKit",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Log",
            targets: ["Log"]
        ),
        .library(
            name: "SwiftyNodeKit",
            targets: ["SwiftyNodeKit"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Log"
        ),
        .target(
            name: "Socket",
            dependencies: ["Log"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "SwiftyNodeKit",
            dependencies: ["Log", "Socket"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
