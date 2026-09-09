// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WoosmapGeofencingCore",
    // iOS 13 is the real floor, not a preference: the SDK uses Swift concurrency
    // (`Task { @MainActor in … }`, added in #153), which does not exist below it.
    // Declaring .v11 made every SPM build fail with "'Task' is only available in
    // iOS 13.0 or newer". 13.0 also matches WoosmapGeofencingCore.podspec.
    platforms: [.iOS(.v13)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "WoosmapGeofencingCore",
            targets: ["WoosmapGeofencingCore"])
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "WoosmapGeofencingCore",
            path: "Sources/WoosmapGeofencing", resources: [.process("Business Logic/Woosmap.xcdatamodeld")]),
        .testTarget(
            name: "WoosmapGeofencingTests",
            dependencies: ["WoosmapGeofencingCore"],
            path: "Tests/WoosmapGeofencingTests")
    ]
)
