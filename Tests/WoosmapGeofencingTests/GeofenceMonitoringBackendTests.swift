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
    override func requestAlwaysAuthorization() {}
    override func startUpdatingLocation() {}
    override func stopUpdatingLocation() {}
    override func startMonitoringSignificantLocationChanges() {}
    override func stopMonitoringSignificantLocationChanges() {}
    override func startMonitoringVisits() {}
}

/// Records what the service asked the backend to do.
final class RecordingBackend: GeofenceMonitoringBackend {
    var onTransition: ((GeofenceTransition) -> Void)?

    /// Stands in for a `CLLocationManager`-style backend: reports crossings only,
    /// never an initial state.
    let reportsInitialState = false

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

    // MARK: - Fixture

    private func makeServiceWithRecordingBackend() -> (LocationServiceCoreImpl, RecordingBackend) {
        let service = LocationServiceCoreImpl(locationManger: FakeLocationManager())
        let recorder = RecordingBackend()
        service.monitoringBackend = recorder
        return (service, recorder)
    }
}
