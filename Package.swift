// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cacherun",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "cacherun", targets: ["cacherun"]),
        .library(name: "CacheExecutor", targets: ["CacheExecutor"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "0.4.0")),
        .package(url: "https://github.com/apple/swift-tools-support-core", .upToNextMajor(from: "0.2.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "cacherun",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
                .target(name: "CacheExecutor")
            ]),
        .target(name: "CacheExecutor",
                dependencies: [
                    .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core")
                ]),
        .testTarget(
            name: "cacherunTests",
            dependencies: ["cacherun"]),
    ]
)
