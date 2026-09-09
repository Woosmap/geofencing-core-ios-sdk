//
//  MonitoringSeamTests.swift
//  WoosmapGeofencingCoreTests
//
//  Covers the parts of the CLMonitor seam that live in `LocationServiceCoreImpl`
//  — the unified region query, the synthesis back to `CLCircularRegion`, the
//  suppression of the manual "already inside" check, and the transition mapping —
//  plus `RegionsGenerator`, whose 13-region grid the whole slot budget rests on
//  and which had no core-side test at all.
//
//  Copyright © 2026 Web Geo Services. All rights reserved.
//

import XCTest
import CoreLocation
@testable import WoosmapGeofencingCore

final class MonitoringSeamTests: XCTestCase {

    private let anchor = CLLocationCoordinate2D(latitude: 43.6053862, longitude: 3.8793329)
    private let beaconUUID = UUID(uuidString: "8DEEFBB9-F738-4297-8040-96668BB44281")!

    private var service: LocationServiceCoreImpl!
    private var manager: FakeLocationManager!
    private var backend: RecordingBackend!

    override func setUp() {
        super.setUp()
        Regions.deleteAll()
        DurationLogs.deleteAll()
        manager = FakeLocationManager()
        service = LocationServiceCoreImpl(locationManger: manager)
        backend = RecordingBackend()
        service.monitoringBackend = backend
    }

    override func tearDown() {
        Regions.deleteAll()
        DurationLogs.deleteAll()
        service = nil
        manager = nil
        backend = nil
        super.tearDown()
    }

    private func geofence(_ identifier: String, radius: CLLocationDistance = 120) -> CircularGeofence {
        CircularGeofence(identifier: identifier, center: anchor, radius: radius)
    }

    private func beacon(_ identifier: String) -> CLBeaconRegion {
        CLBeaconRegion(uuid: beaconUUID, major: 1, minor: 1,
                       identifier: "\(RegionType.poi.rawValue)<id>\(identifier)<id>")
    }

    // MARK: - Unified region query

    /// Region listings must come from the backend. Reading `CLLocationManager`
    /// would return empty once monitoring moves to `CLMonitor`, silently emptying
    /// the public `updateRegions(regions:)`.
    func test_unifiedQuery_reportsBackendGeofences() {
        backend.monitoredGeofences = [geofence("poi<id>store-A<id>")]

        XCTAssertEqual(service.monitoredRegionsUnified.map { $0.identifier },
                       ["poi<id>store-A<id>"])
        XCTAssertTrue(manager.monitoredRegions.isEmpty)
    }

    /// Beacons stay on `CLLocationManager`, so the query is a union of the two.
    func test_unifiedQuery_unionsBeaconsFromTheLocationManager() {
        backend.monitoredGeofences = [geofence("poi<id>store-A<id>")]
        let beaconRegion = beacon("beacon-1")
        manager.startMonitoring(for: beaconRegion)

        let regions = service.monitoredRegionsUnified

        XCTAssertEqual(regions.count, 2)
        XCTAssertTrue(regions.contains(beaconRegion))
        XCTAssertTrue(regions.contains { $0 is CLCircularRegion })
    }

    /// A circular region left on the manager must not be double-counted: the
    /// backend is the single source of truth for those.
    func test_unifiedQuery_ignoresCircularRegionsLeftOnTheManager() {
        manager.startMonitoring(for: CLCircularRegion(center: anchor, radius: 100,
                                                      identifier: "poi<id>stale<id>"))

        XCTAssertTrue(service.monitoredRegionsUnified.isEmpty)
    }

    func test_unifiedQuery_isEmptyWhenNothingIsMonitored() {
        XCTAssertTrue(service.monitoredRegionsUnified.isEmpty)
    }

    // MARK: - Synthesis back to CLCircularRegion

    /// The public API is typed on `CLRegion`, so geofences are rebuilt into
    /// `CLCircularRegion`. Consumers read the geometry, so it has to survive.
    func test_synthesis_preservesIdentifierCentreAndRadius() {
        backend.monitoredGeofences = [geofence("custom<id>my-zone", radius: 275)]

        let region = service.monitoredRegionsUnified.first as? CLCircularRegion

        XCTAssertEqual(region?.identifier, "custom<id>my-zone")
        XCTAssertEqual(region?.center.latitude, anchor.latitude)
        XCTAssertEqual(region?.center.longitude, anchor.longitude)
        XCTAssertEqual(region?.radius, 275)
    }

    /// Reconstruction is only lossless because these flags are never customised
    /// anywhere in Sources. If that ever changes, synthesis starts dropping them.
    func test_synthesis_yieldsTheDefaultNotifyFlags() {
        backend.monitoredGeofences = [geofence("poi<id>store-A<id>")]

        let region = service.monitoredRegionsUnified.first as? CLCircularRegion

        XCTAssertEqual(region?.notifyOnEntry, true)
        XCTAssertEqual(region?.notifyOnExit, true)
    }

    // MARK: - The manual "already inside" check

    /// Under `CLMonitor` the platform reports a seeded region's initial state, so
    /// running the manual check as well would deliver the enter twice.
    func test_manualCheck_standsDownWhenTheBackendReportsInitialState() {
        backend.reportsInitialState = true
        service.currentLocation = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
        let delegate = RegionRecorder()
        service.regionDelegate = delegate

        service.checkIfUserIsInRegionUnlessBackendReports(
            region: CLCircularRegion(center: anchor, radius: 100, identifier: "custom<id>my-zone"))

        XCTAssertTrue(delegate.entered.isEmpty)
    }

    /// `CLLocationManager` reports only crossings, so under the legacy backend the
    /// manual check is the only thing that produces the "already inside" event.
    func test_manualCheck_runsWhenTheBackendDoesNotReportInitialState() {
        backend.reportsInitialState = false
        service.currentLocation = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
        let delegate = RegionRecorder()
        service.regionDelegate = delegate

        service.checkIfUserIsInRegionUnlessBackendReports(
            region: CLCircularRegion(center: anchor, radius: 100, identifier: "custom<id>my-zone"))

        XCTAssertEqual(delegate.entered.count, 1)
        XCTAssertEqual(delegate.entered.first?.fromPositionDetection, true)
    }

    // MARK: - stopMonitoring type dispatch

    /// POI beacons and POI circles share the `poi<id>…<id>` scheme, so callers
    /// holding a bare `CLRegion` cannot know which they have. The helper decides.
    func test_stopMonitoring_routesCircularRegionsToTheBackend() {
        let region = CLCircularRegion(center: anchor, radius: 100, identifier: "poi<id>store-A<id>")

        service.stopMonitoring(region)

        XCTAssertEqual(backend.stopped, ["poi<id>store-A<id>"])
    }

    func test_stopMonitoring_routesBeaconsToTheLocationManager() {
        let beaconRegion = beacon("beacon-1")
        manager.startMonitoring(for: beaconRegion)

        service.stopMonitoring(beaconRegion)

        XCTAssertTrue(backend.stopped.isEmpty, "beacons bypass the abstraction")
        XCTAssertTrue(manager.monitoredRegions.isEmpty, "but are still stopped")
    }

    // MARK: - RegionsGenerator, which the slot budget depends on

    /// The 13 reserved slots are not a magic number: they are exactly what the
    /// generator lays down for a stationary user.
    func test_grid_isThirteenRegionsForAStationaryUser() {
        let grid = RegionsGenerator().generateRegionsFrom(
            location: CLLocation(latitude: anchor.latitude, longitude: anchor.longitude))

        XCTAssertEqual(grid.count, 13, "8 directional translations + 5 concentric radiuses")
        XCTAssertTrue(grid.allSatisfy { service.getRegionType(identifier: $0.identifier) == .position })
    }

    /// Above 10 m/s the three tightest rings are dropped, so a moving user
    /// occupies fewer slots than the reservation assumes.
    func test_grid_dropsTightRingsAtSpeed() {
        let fast = CLLocation(coordinate: anchor, altitude: 0,
                              horizontalAccuracy: 10, verticalAccuracy: 10,
                              course: 0, speed: 20, timestamp: Date())

        XCTAssertEqual(RegionsGenerator().generateRegionsFrom(location: fast).count, 10)
    }

    /// The rings are centred on the user, which is what makes seeding them
    /// `.satisfied` a certainty rather than a guess.
    func test_grid_ringsAreCentredOnTheUser() {
        let grid = RegionsGenerator().generateRegionsFrom(
            location: CLLocation(latitude: anchor.latitude, longitude: anchor.longitude))

        let rings = grid.compactMap { $0 as? CLCircularRegion }
            .filter { $0.identifier.hasPrefix("\(RegionType.position.rawValue)_radius") }

        XCTAssertEqual(rings.count, 5)
        for ring in rings {
            XCTAssertEqual(ring.center.latitude, anchor.latitude, accuracy: 0.000001, ring.identifier)
            XCTAssertEqual(ring.center.longitude, anchor.longitude, accuracy: 0.000001, ring.identifier)
        }
    }

    /// The translations are offset far enough that the user is outside them, which
    /// is what makes seeding them `.unsatisfied` equally certain.
    func test_grid_translationsPlaceTheUserOutside() {
        let fix = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
        let grid = RegionsGenerator().generateRegionsFrom(location: fix)

        let translations = grid.compactMap { $0 as? CLCircularRegion }
            .filter { $0.identifier.contains("translation") }

        XCTAssertEqual(translations.count, 8)
        for cell in translations {
            let centre = CLLocation(latitude: cell.center.latitude, longitude: cell.center.longitude)
            XCTAssertGreaterThan(fix.distance(from: centre), cell.radius,
                                 "\(cell.identifier) should not contain the user")
        }
    }

    // MARK: - Backend selection

    /// One construction site chooses the implementation for the running OS.
    func test_theServiceSelectsABackendForTheRunningOS() {
        let fresh = LocationServiceCoreImpl(locationManger: FakeLocationManager())

        if #available(iOS 17.0, *) {
            XCTAssertTrue(fresh.monitoringBackend is CLMonitorBackend)
            XCTAssertTrue(fresh.monitoringBackend.reportsInitialState)
        } else {
            XCTAssertTrue(fresh.monitoringBackend is LegacyRegionBackend)
            XCTAssertFalse(fresh.monitoringBackend.reportsInitialState)
        }
    }
}

/// Minimal region delegate recorder for these tests.
private final class RegionRecorder: RegionsServiceDelegate {
    private(set) var entered: [Region] = []
    private(set) var exited: [Region] = []
    func updateRegions(regions: Set<CLRegion>) {}
    func didEnterPOIRegion(POIregion: Region) { entered.append(POIregion) }
    func didExitPOIRegion(POIregion: Region) { exited.append(POIregion) }
    func workZOIEnter(classifiedRegion: Region) {}
    func homeZOIEnter(classifiedRegion: Region) {}
}
