//
//  GeofenceMonitoringBackend.swift
//  WoosmapGeofencingCore
//
//  The seam between the SDK's geofencing logic and the platform API that actually
//  performs the monitoring. Introduced by the CLMonitor migration (issue #166) so a
//  later phase can swap the implementation without touching the callers.
//

import Foundation
import CoreLocation

/// A circular geofence transition observed by a monitoring backend.
internal struct GeofenceTransition {

    /// Identifier of the region that was crossed, in the SDK's own
    /// `poi<id>…<id>` / `custom<id>…` / `position…` scheme.
    let identifier: String

    /// Centre of the region, needed by `addRegionLogTransition` to cross-check the
    /// transition against the last known fix.
    let center: CLLocationCoordinate2D

    /// Radius of the region, in metres.
    let radius: CLLocationDistance

    let didEnter: Bool

    /// `true` when the backend is reporting the state a region was *already* in
    /// when monitoring began, rather than a boundary the user has just crossed.
    ///
    /// The legacy backend never sets this: `CLLocationManager` only reports actual
    /// crossings to `didEnterRegion` / `didExitRegion`. It exists for `CLMonitor`,
    /// which delivers an initial state per region on registration.
    let initialState: Bool
}

/// Performs circular-region monitoring on behalf of `LocationServiceCoreImpl`.
///
/// Beacons deliberately do **not** go through this protocol — they keep talking to
/// `CLLocationManager` directly, because `CLMonitor` has no beacon equivalent.
internal protocol GeofenceMonitoringBackend: AnyObject {

    /// Identifiers of every circular region currently monitored.
    ///
    /// Beacon regions are excluded even though they share the `poi<id>…<id>`
    /// identifier scheme.
    var monitoredCircularIdentifiers: Set<String> { get }

    /// Invoked for every transition the backend observes.
    var onTransition: ((GeofenceTransition) -> Void)? { get set }

    /// Begins monitoring a circular geofence. Replaces any region already
    /// monitored under the same identifier, matching `CLLocationManager`.
    func start(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance)

    /// Stops monitoring the circular geofence with this identifier. A beacon
    /// sharing the identifier is left alone.
    func stop(identifier: String)

    /// Feeds a platform-level region event into the backend, which normalises it
    /// and re-emits it through `onTransition`.
    ///
    /// Only the legacy backend needs this, because `CLLocationManagerDelegate` is
    /// implemented by the service rather than by the backend. A `CLMonitor` backend
    /// owns its own event stream and drives `onTransition` directly.
    func reportPlatformEvent(region: CLCircularRegion, didEnter: Bool)
}

/// Monitoring backend that preserves the pre-migration behaviour exactly:
/// `CLCircularRegion` plus `startMonitoring(for:)` / `stopMonitoring(for:)`.
internal final class LegacyRegionBackend: GeofenceMonitoringBackend {

    /// Resolved on each use rather than captured once, because
    /// `LocationServiceCoreImpl.locationManager` is replaced when tracking is
    /// toggled and by tests installing a fake.
    private let locationManager: () -> LocationManagerProtocol?

    var onTransition: ((GeofenceTransition) -> Void)?

    init(locationManager: @escaping () -> LocationManagerProtocol?) {
        self.locationManager = locationManager
    }

    var monitoredCircularIdentifiers: Set<String> {
        Set(circularRegions().map { $0.identifier })
    }

    func start(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        locationManager()?.startMonitoring(for: CLCircularRegion(center: center,
                                                                 radius: radius,
                                                                 identifier: identifier))
    }

    func stop(identifier: String) {
        guard let manager = locationManager() else { return }
        for region in circularRegions() where region.identifier == identifier {
            manager.stopMonitoring(for: region)
        }
    }

    func reportPlatformEvent(region: CLCircularRegion, didEnter: Bool) {
        onTransition?(GeofenceTransition(identifier: region.identifier,
                                         center: region.center,
                                         radius: region.radius,
                                         didEnter: didEnter,
                                         initialState: false))
    }

    private func circularRegions() -> [CLCircularRegion] {
        (locationManager()?.monitoredRegions ?? []).compactMap { $0 as? CLCircularRegion }
    }
}
