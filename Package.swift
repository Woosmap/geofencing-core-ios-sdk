// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WoosmapGeofencingCore",
    platforms: [.iOS(.v11)],
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
