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
            name: "SwiftyNodeKit",
            targets: ["SwiftyNodeKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/BlueSocket.git", branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftyNodeKit",
            dependencies: [
                .product(name: "Socket", package: "BlueSocket")
            ]
        ),
    ]
)
