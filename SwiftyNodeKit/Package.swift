// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

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
        ),
        .library(
            name: "NodeMacro",
            targets: ["NodeMacro"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
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
        ),
        .macro(
            name: "NodeMacroMacros",
            dependencies: [
                "Log",
                "SwiftyNodeKit",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            path: "Sources/Macro/NodeMacroMacros"
        ),
        .target(
            name: "NodeMacro",
            dependencies: ["NodeMacroMacros"],
            path: "Sources/Macro/NodeMacro"
        ),
    ]
)
