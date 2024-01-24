// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "APIServices",
    platforms: [.iOS(.v15), .watchOS(.v6), .macOS("12")],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "APIServices",
            targets: ["APIServices"]
        ),
        .plugin(name: "SwiftLint", targets: ["SwiftLint"]),
        .plugin(name: "SwiftLintFix", targets: ["SwiftLintFix"])
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.

        .target(
            name: "APIServices",
            dependencies: [],
            plugins: ["SwiftLint"]
        ),
        .testTarget(
            name: "APIServicesTests",
            dependencies: ["APIServices"],
            resources: [.copy("MockJSON")]
        ),

        // SwiftLint
        .binaryTarget(
            name: "SwiftLintBinary",
            url: "https://github.com/realm/SwiftLint/releases/download/0.50.3/SwiftLintBinary-macos.artifactbundle.zip",
            checksum: "abe7c0bb505d26c232b565c3b1b4a01a8d1a38d86846e788c4d02f0b1042a904"
        ),

        .plugin(
            name: "SwiftLint",
            capability: .buildTool(),
            dependencies: ["SwiftLintBinary"]
        ),

        .plugin(
            name: "SwiftLintFix",
            capability: .command(
                intent: .sourceCodeFormatting(),
                permissions: [.writeToPackageDirectory(reason: "Fixes fixable lint issues")]
            ),
            dependencies: ["SwiftLintBinary"]
        )
    ]
)
