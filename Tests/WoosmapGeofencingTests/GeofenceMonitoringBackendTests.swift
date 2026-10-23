//
//  GeofenceMonitoringBackendTests.swift
//  WoosmapGeofencingCoreTests
//
//  Covers the monitoring seam introduced by the CLMonitor migration: that
//  `LegacyRegionBackend` reaches CLLocationManager, that it leaves beacons alone
//  even though they share the POI identifier scheme, and that
//  `LocationServiceCoreImpl` routes its circular writes through whatever backend
//  is installed.
//
//  Copyright © 2026 Web Geo Services. All rights reserved.
//

import XCTest
import CoreLocation
@testable import WoosmapGeofencingCore

/// In-memory stand-in for CLLocationManager's region registry.
final class FakeLocationManager: LocationManagerProtocol {
    private var regions = Set<CLRegion>()
    override var monitoredRegions: Set<CLRegion> { regions }
    override func startMonitoring(for region: CLRegion) { regions.insert(region) }
    override func stopMonitoring(for region: CLRegion) { regions.remove(region) }
    override func startMonitoringVisits() {}

    /// Drives the authorization branches. `CLLocationManager.authorizationStatus`
    /// reflects the host process, which a test cannot change.
    var stubbedAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    override var authorizationStatus: CLAuthorizationStatus { stubbedAuthorizationStatus }

    /// Whether the host app declared the background location mode. The real
    /// setter raises when the entitlement is absent, which it is in a test
    /// bundle, so it is stubbed rather than set.
    var stubbedAllowsBackgroundLocationUpdates = false
    override var allowsBackgroundLocationUpdates: Bool {
        get { stubbedAllowsBackgroundLocationUpdates }
        set { stubbedAllowsBackgroundLocationUpdates = newValue }
    }

    private(set) var alwaysAuthorizationRequests = 0
    private(set) var whenInUseAuthorizationRequests = 0
    private(set) var startUpdatingCalls = 0
    private(set) var stopUpdatingCalls = 0
    private(set) var significantChangeStarts = 0

    override func requestAlwaysAuthorization() { alwaysAuthorizationRequests += 1 }
    override func requestWhenInUseAuthorization() { whenInUseAuthorizationRequests += 1 }
    override func startUpdatingLocation() { startUpdatingCalls += 1 }
    override func stopUpdatingLocation() { stopUpdatingCalls += 1 }
    override func startMonitoringSignificantLocationChanges() { significantChangeStarts += 1 }
    override func stopMonitoringSignificantLocationChanges() {}
}

/// Records what the service asked the backend to do.
final class RecordingBackend: GeofenceMonitoringBackend {
    var onTransition: (@Sendable (GeofenceTransition) -> Void)?

    /// `false` presents a `CLLocationManager`-shaped backend, reporting crossings
    /// only. Set it to `true` to present a `CLMonitor`-shaped one, which reports a
    /// region's initial state itself. Settable rather than two doubles, so there
    /// is one recorder to keep in step with the protocol.
    var reportsInitialState = false

    /// `false` presents a backend with its own store, the shape that has legacy
    /// regions to adopt. `true` presents a `CLLocationManager`-backed one.
    var usesPlatformRegionStore = false

    var monitoredGeofences: [CircularGeofence] = []

    private(set) var started: [(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance)] = []
    private(set) var stopped: [String] = []
    private(set) var reported: [(identifier: String, didEnter: Bool)] = []

    func start(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        started.append((identifier, center, radius))
    }

    func stop(identifier: String) {
        stopped.append(identifier)
    }

    /// Recorded separately from `stopped`, so a test can tell a teardown that went
    /// through the backend apart from one that looped identifiers.
    private(set) var stopAllCalls = 0
    func stopAll() {
        stopAllCalls += 1
        stopped.append(contentsOf: monitoredGeofences.map { $0.identifier })
        monitoredGeofences.removeAll()
    }

    func reportPlatformEvent(region: CLCircularRegion, didEnter: Bool) {
        reported.append((region.identifier, didEnter))
    }
}

final class GeofenceMonitoringBackendTests: XCTestCase {

    private let anchor = CLLocationCoordinate2D(latitude: 43.6053862, longitude: 3.8793329)
    private let beaconUUID = UUID(uuidString: "8DEEFBB9-F738-4297-8040-96668BB44281")!

    private var manager: FakeLocationManager!
    private var backend: LegacyRegionBackend!

    override func setUp() {
        super.setUp()
        manager = FakeLocationManager()
        backend = LegacyRegionBackend(locationManager: { [weak self] in self?.manager })
    }

    override func tearDown() {
        backend = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - LegacyRegionBackend reaches the manager

    func test_start_registersACircularRegion() {
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)

        let region = manager.monitoredRegions.first as? CLCircularRegion
        XCTAssertEqual(manager.monitoredRegions.count, 1)
        XCTAssertEqual(region?.identifier, "poi<id>store-A<id>")
        XCTAssertEqual(region?.center.latitude, anchor.latitude)
        XCTAssertEqual(region?.center.longitude, anchor.longitude)
        XCTAssertEqual(region?.radius, 120)
    }

    func test_stop_removesTheMatchingRegion() {
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)
        backend.start(identifier: "poi<id>store-B<id>", center: anchor, radius: 120)

        backend.stop(identifier: "poi<id>store-A<id>")

        XCTAssertEqual(backend.monitoredCircularIdentifiers, ["poi<id>store-B<id>"])
    }

    func test_stop_forAnUnknownIdentifier_isANoOp() {
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)

        backend.stop(identifier: "poi<id>absent<id>")

        XCTAssertEqual(manager.monitoredRegions.count, 1)
    }

    func test_monitoredCircularIdentifiers_isEmptyWithoutAManager() {
        XCTAssertTrue(LegacyRegionBackend(locationManager: { nil }).monitoredCircularIdentifiers.isEmpty)
    }

    /// The manager is resolved per call, not captured, because the service swaps it
    /// when tracking is toggled.
    func test_backendFollowsAReplacedManager() {
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)
        XCTAssertEqual(backend.monitoredCircularIdentifiers.count, 1)

        manager = FakeLocationManager()

        XCTAssertTrue(backend.monitoredCircularIdentifiers.isEmpty)
    }

    // MARK: - Beacons stay outside the abstraction

    /// Beacons use the same `poi<id>…<id>` identifiers as POI circles, so an
    /// identifier-keyed backend could evict one by accident. It must not.
    func test_stop_neverRemovesABeaconSharingTheIdentifier() {
        let beacon = CLBeaconRegion(uuid: beaconUUID, major: 1, minor: 1, identifier: "poi<id>shared<id>")
        manager.startMonitoring(for: beacon)
        backend.start(identifier: "poi<id>shared<id>", center: anchor, radius: 120)

        backend.stop(identifier: "poi<id>shared<id>")

        XCTAssertEqual(manager.monitoredRegions.count, 1)
        XCTAssertTrue(manager.monitoredRegions.contains(beacon), "the beacon survives")
    }

    func test_monitoredCircularIdentifiers_excludesBeacons() {
        manager.startMonitoring(for: CLBeaconRegion(uuid: beaconUUID, major: 1, minor: 1,
                                                    identifier: "poi<id>beacon-1<id>"))
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)

        XCTAssertEqual(backend.monitoredCircularIdentifiers, ["poi<id>store-A<id>"])
    }

    // MARK: - Transitions

    func test_reportPlatformEvent_publishesGeometryAlongsideTheIdentifier() {
        var received: [GeofenceTransition] = []
        backend.onTransition = { received.append($0) }

        backend.reportPlatformEvent(region: CLCircularRegion(center: anchor, radius: 120,
                                                             identifier: "poi<id>store-A<id>"),
                                    didEnter: true)

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.identifier, "poi<id>store-A<id>")
        XCTAssertEqual(received.first?.didEnter, true)
        XCTAssertEqual(received.first?.center.latitude, anchor.latitude)
        XCTAssertEqual(received.first?.radius, 120)
        XCTAssertEqual(received.first?.initialState, false,
                       "CLLocationManager only ever reports real crossings")
    }

    // MARK: - The service routes through whatever backend is installed

    func test_addRegion_startsThroughTheBackend() {
        let (service, recorder) = makeServiceWithRecordingBackend()

        let (created, identifier) = service.addRegion(identifier: "my-zone", center: anchor, radius: 100)

        XCTAssertTrue(created)
        XCTAssertEqual(identifier, "\(RegionType.custom.rawValue)<id>my-zone")
        XCTAssertEqual(recorder.started.count, 1)
        XCTAssertEqual(recorder.started.first?.identifier, "\(RegionType.custom.rawValue)<id>my-zone")
        XCTAssertEqual(recorder.started.first?.radius, 100)
    }

    func test_removeRegion_stopsThroughTheBackend() {
        let (service, recorder) = makeServiceWithRecordingBackend()
        // Seeded on the backend, not the location manager: the backend is now the
        // source of truth for circular regions, so poking one into the manager
        // would be invisible to the service.
        recorder.monitoredGeofences = [
            CircularGeofence(identifier: "custom<id>my-zone", center: anchor, radius: 100)
        ]

        service.removeRegion(identifier: "custom<id>my-zone")

        XCTAssertEqual(recorder.stopped, ["custom<id>my-zone"])
    }

    /// A beacon must not be handed to the backend even when the caller only holds a
    /// `CLRegion` from `monitoredRegions`.
    func test_removeRegion_forABeacon_bypassesTheBackend() {
        let (service, recorder) = makeServiceWithRecordingBackend()
        let beacon = CLBeaconRegion(uuid: beaconUUID, major: 1, minor: 1, identifier: "poi<id>beacon-1<id>")
        service.locationManager?.startMonitoring(for: beacon)

        service.removeRegion(identifier: "poi<id>beacon-1<id>")

        XCTAssertTrue(recorder.stopped.isEmpty, "beacons bypass the abstraction")
        XCTAssertTrue(service.locationManager?.monitoredRegions.isEmpty ?? false,
                      "but it is still stopped, directly")
    }

    /// Installing a backend must re-wire `onTransition`, or transitions vanish.
    func test_replacingTheBackend_keepsTransitionsWired() {
        let (service, recorder) = makeServiceWithRecordingBackend()

        service.locationManager(CLLocationManager(),
                                didEnterRegion: CLCircularRegion(center: anchor, radius: 100,
                                                                 identifier: "custom<id>my-zone"))

        XCTAssertEqual(recorder.reported.count, 1, "the event reached the installed backend")
        XCTAssertEqual(recorder.reported.first?.didEnter, true)
        XCTAssertNotNil(recorder.onTransition, "and its hook was wired on assignment")
    }

    /// One crossing must restart the services once.
    ///
    /// On the legacy backend `reportPlatformEvent` reaches `handle(transition:)`
    /// synchronously, and that calls `handleRegionChange()`. While
    /// `handlePlatformRegionEvent` called it again afterwards, every crossing on
    /// iOS 15.0 to 17.1 ran the cycle twice: the grid torn down, then a second
    /// teardown against an empty set, and two service restarts.
    ///
    /// No test could see it, because none counted restarts — they asserted the
    /// transition arrived, not how much work it caused. The device captures could
    /// not see it either: all of them were on 17.2+, where `CLMonitor` owns the
    /// events and this path is never reached.
    func test_legacyCrossing_restartsTheServicesExactlyOnce() {
        let manager = FakeLocationManager()
        manager.stubbedAuthorizationStatus = .authorizedAlways
        let service = LocationServiceCoreImpl(locationManger: manager)
        service.monitoringBackend = LegacyRegionBackend(locationManager: { manager })
        trackingEnable = true
        defer { trackingEnable = false }

        let before = (manager.significantChangeStarts, manager.startUpdatingCalls)
        service.locationManager(CLLocationManager(),
                                didEnterRegion: CLCircularRegion(center: anchor, radius: 100,
                                                                 identifier: "poi<id>bakery<id>"))

        XCTAssertEqual(manager.significantChangeStarts - before.0, 1,
                       "one crossing, one significant-change restart")
        XCTAssertEqual(manager.startUpdatingCalls - before.1, 1,
                       "and one location-update restart")
    }

    /// The gate in `handle(transition:)`, on the backend that actually has initial
    /// states to gate.
    ///
    /// Its own comment says missing either half of the seeding silently kills the grid
    /// wake-up, and it is what stops a Search API refresh registering N conditions from
    /// running N teardown cycles. `test_legacyCrossing_restartsTheServicesExactlyOnce`
    /// covers the legacy path, where `initialState` is hardcoded false and the gate is
    /// therefore inert — so nothing covered the branch that matters.
    func test_initialDeterminationFromTheBackend_doesNotRestartServices() {
        let manager = FakeLocationManager()
        manager.stubbedAuthorizationStatus = .authorizedAlways
        let service = LocationServiceCoreImpl(locationManger: manager)
        let backend = RecordingBackend()
        backend.reportsInitialState = true
        service.monitoringBackend = backend
        trackingEnable = true
        defer { trackingEnable = false }

        let before = (manager.significantChangeStarts, manager.startUpdatingCalls)
        backend.onTransition?(GeofenceTransition(identifier: "poi<id>bakery<id>",
                                                 center: anchor, radius: 150,
                                                 didEnter: true, initialState: true))

        XCTAssertEqual(manager.significantChangeStarts - before.0, 0,
                       "a determination is CoreLocation reporting where we already were")
        XCTAssertEqual(manager.startUpdatingCalls - before.1, 0)
    }

    /// And a real crossing on the same backend restarts exactly once — so the gate is
    /// not simply refusing everything.
    func test_crossingFromTheBackend_restartsServicesExactlyOnce() {
        let manager = FakeLocationManager()
        manager.stubbedAuthorizationStatus = .authorizedAlways
        let service = LocationServiceCoreImpl(locationManger: manager)
        let backend = RecordingBackend()
        backend.reportsInitialState = true
        service.monitoringBackend = backend
        trackingEnable = true
        defer { trackingEnable = false }

        let before = (manager.significantChangeStarts, manager.startUpdatingCalls)
        backend.onTransition?(GeofenceTransition(identifier: "poi<id>bakery<id>",
                                                 center: anchor, radius: 150,
                                                 didEnter: false, initialState: false))

        XCTAssertEqual(manager.significantChangeStarts - before.0, 1)
        XCTAssertEqual(manager.startUpdatingCalls - before.1, 1)
    }

    /// `stopAllCalls` exists so a test can tell a teardown that went through the backend
    /// apart from one that looped identifiers. Asserting it here keeps the counter from
    /// being dead weight on core's own recorder.
    func test_recordingBackend_stopAllClearsWhatItHeld() {
        let backend = RecordingBackend()
        backend.monitoredGeofences = [
            CircularGeofence(identifier: "poi<id>a<id>", center: anchor, radius: 100),
            CircularGeofence(identifier: "custom<id>my-zone", center: anchor, radius: 100),
        ]

        backend.stopAll()

        XCTAssertEqual(backend.stopAllCalls, 1)
        XCTAssertEqual(Set(backend.stopped), ["poi<id>a<id>", "custom<id>my-zone"])
        XCTAssertTrue(backend.monitoredGeofences.isEmpty)
    }


    // MARK: - Fixture

    private func makeServiceWithRecordingBackend() -> (LocationServiceCoreImpl, RecordingBackend) {
        let service = LocationServiceCoreImpl(locationManger: FakeLocationManager())
        let recorder = RecordingBackend()
        service.monitoringBackend = recorder
        return (service, recorder)
    }
}
