// swift-tools-version: 6.2
//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Mocking",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Mocking", targets: ["Mocking"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ],
    targets: [
        .macro(
            name: "MockingMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Sources/MockingMacros"
        ),
        .target(
            name: "Mocking",
            dependencies: [
                "MockingMacros",
            ],
            path: "Sources/Mocking"
        ),
        .testTarget(
            name: "MockingTests",
            dependencies: [
                "Mocking",
                "MockingMacros",
            ],
            path: "Tests",
            exclude: ["MockingMacrosTests"]
        ),
        // Uses SwiftSyntaxMacrosGenericTestSupport (prebuilt), not MacroTesting, to skip swift-syntax source build.
        .testTarget(
            name: "MockingMacrosTests",
            dependencies: [
                "MockingMacros",
                // Required to link the macro plugin into the test executable on Linux.
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
            ],
            path: "Tests/MockingMacrosTests"
        ),
    ]
)

// Adopt Swift's approachable-concurrency upcoming features across every target.
// No `MOCKING` define here: debug builds already carry `DEBUG`, which the gates accept.
for target in package.targets {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]
}
