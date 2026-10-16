// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WoosmapGeofencingCore",
    // 15.0 across all three manifests. The xcodeproj had to move there because
    // Xcode 27 refuses any deployment target below it — which made core
    // unbuildable, framework included — and the podspec follows it, so a
    // consumer gets the same answer however it integrates.
    //
    // The tools version above is 5.10, matching the podspec's `swift_versions`.
    // It is set by what the sources actually need, not by `.v15` (which only needs
    // 5.5). Three things set it, and the highest wins:
    //   - `CLMonitor` exists only in the iOS 17 SDK, so nothing below Xcode 15 builds.
    //   - `CLServiceSession` and the iOS 18 `CLMonitor.Event` diagnostic flags need the
    //     iOS 18 SDK, so nothing below Xcode 16 builds — the `@available` guards on
    //     them gate *running*, not compiling.
    //   - `nonisolated(unsafe)` on `MonitorSession.sessions` is a Swift 5.10 feature.
    // It said 5.9 while the last two were already in the sources, which would have let
    // SPM accept the package on a toolchain that then failed to compile it.
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
