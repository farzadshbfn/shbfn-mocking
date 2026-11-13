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
    traits: [
        .trait(
            name: "Dependencies",
            description: "Adds @MockableDependency, which registers a mock as a swift-dependencies key."
        ),
    ],
    dependencies: [
        // Open upper bound: each Swift release bumps the swift-syntax major, and a cap blocks its prebuilts.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "604.0.0"..<"700.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.17.2"),
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
                .product(
                    name: "Dependencies",
                    package: "swift-dependencies",
                    condition: .when(traits: ["Dependencies"])
                ),
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
            exclude: ["MockingMacrosTests", "MockingDependenciesTests"]
        ),
        .testTarget(
            name: "MockingDependenciesTests",
            dependencies: [
                "Mocking",
                .product(
                    name: "DependenciesTestSupport",
                    package: "swift-dependencies",
                    condition: .when(traits: ["Dependencies"])
                ),
            ],
            path: "Tests/MockingDependenciesTests"
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
