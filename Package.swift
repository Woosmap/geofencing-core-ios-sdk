// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WoosmapGeofencingCore",
    // 15.0 across all three manifests. The xcodeproj had to move there because
    // Xcode 27 refuses any deployment target below it — which made core
    // unbuildable, framework included — and the podspec follows it, so a
    // consumer gets the same answer however it integrates.
    //
    // The tools version above is 5.5 because of this line: `.v15` is only
    // available from PackageDescription 5.5, and 5.3 fails to compile the
    // manifest at all.
    //
    // Whatever a later toolchain allows, do not take this below 13: the SDK has
    // used Swift concurrency (`Task { @MainActor in … }`) since #153, and .v11
    // made every SPM build fail with "'Task' is only available in iOS 13.0 or
    // newer".
    platforms: [.iOS(.v15)],
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
