//
//  AuthorizationAndVisitTests.swift
//  WoosmapGeofencingCoreTests
//
//  Covers the behaviour added after the architecture review on #43: the
//  `requestAuthorization` switch, the latch that starts services on the first
//  authorized callback, the API-key masking, and the `updateVisit` guards.
//
//  All of it was shipped untested, and both defects found on that branch so far
//  lived in the untested part of the diff.
//

import CoreLocation
import XCTest
@testable import WoosmapGeofencingCore

final class AuthorizationTests: XCTestCase {

    private var manager: FakeLocationManager!
    private var service: LocationServiceCoreImpl!

    override func setUp() {
        super.setUp()
        manager = FakeLocationManager()
        service = LocationServiceCoreImpl(locationManger: manager)
    }

    override func tearDown() {
        trackingEnable = false
        service = nil
        manager = nil
        super.tearDown()
    }

    // MARK: - requestAuthorization

    /// Nothing has been asked yet, and the host app declared the background mode,
    /// so ask for the authorization that mode needs.
    func test_requestAuthorization_asksForAlwaysWhenBackgroundUpdatesAreAllowed() {
        manager.stubbedAuthorizationStatus = .notDetermined
        manager.stubbedAllowsBackgroundLocationUpdates = true
        service.requestAuthorization()
        XCTAssertEqual(manager.alwaysAuthorizationRequests, 1)
        XCTAssertEqual(manager.whenInUseAuthorizationRequests, 0)
    }

    /// Without the background mode, Always is more than the app can use, so the
    /// SDK asks only for when-in-use rather than putting the heavier prompt in
    /// front of the user on the integrator's behalf.
    func test_requestAuthorization_asksOnlyForWhenInUseWithoutBackgroundUpdates() {
        manager.stubbedAuthorizationStatus = .notDetermined
        manager.stubbedAllowsBackgroundLocationUpdates = false
        service.requestAuthorization()
        XCTAssertEqual(manager.whenInUseAuthorizationRequests, 1)
        XCTAssertEqual(manager.alwaysAuthorizationRequests, 0)
    }

    /// The escalation: an app holding when-in-use is asked to upgrade. iOS never
    /// grants Always on a first ask, so this is the only route to it — and it is
    /// also the SDK asking on the integrator's behalf, which is why it is pinned
    /// here rather than left implicit.
    func test_requestAuthorization_escalatesFromWhenInUseWhenBackgroundUpdatesAreAllowed() {
        manager.stubbedAuthorizationStatus = .authorizedWhenInUse
        manager.stubbedAllowsBackgroundLocationUpdates = true
        service.requestAuthorization()
        XCTAssertEqual(manager.alwaysAuthorizationRequests, 1)
    }

    /// The escalation is gated on the background mode. An app that never asked
    /// for background location gets no upgrade prompt from the SDK — it already
    /// holds everything it declared it can use.
    func test_requestAuthorization_doesNotEscalateWithoutBackgroundUpdates() {
        manager.stubbedAuthorizationStatus = .authorizedWhenInUse
        manager.stubbedAllowsBackgroundLocationUpdates = false
        service.requestAuthorization()
        XCTAssertEqual(manager.alwaysAuthorizationRequests, 0)
        XCTAssertEqual(manager.whenInUseAuthorizationRequests, 0,
                       "already held: asking again would be noise")
    }

    /// Already granted. Asking again would be noise.
    func test_requestAuthorization_isSilentWhenAlreadyAlways() {
        manager.stubbedAuthorizationStatus = .authorizedAlways
        service.requestAuthorization()
        XCTAssertEqual(manager.alwaysAuthorizationRequests, 0)
    }

    /// The user said no, or an MDM profile did. Re-prompting is not possible and
    /// pretending otherwise hides the real state.
    func test_requestAuthorization_doesNotNagWhenRefused() {
        for status in [CLAuthorizationStatus.denied, .restricted] {
            manager = FakeLocationManager()
            service = LocationServiceCoreImpl(locationManger: manager)
            manager.stubbedAuthorizationStatus = status
            service.requestAuthorization()
            XCTAssertEqual(manager.alwaysAuthorizationRequests, 0, "\(status.rawValue)")
        }
    }

    // MARK: - starting services on the first grant

    /// Every start path reads the status *before* the user answers the prompt,
    /// finds `.notDetermined` and skips. Without this the app stayed inert on a
    /// first run until it was next backgrounded: measured on device as no arrival
    /// across 80 s of movement, against 10 s once this landed.
    func test_firstAuthorizedCallback_startsServices() {
        trackingEnable = true
        manager.stubbedAuthorizationStatus = .authorizedAlways

        service.locationManager(manager, didChangeAuthorization: .authorizedAlways)

        XCTAssertGreaterThan(manager.startUpdatingCalls, 0)
        XCTAssertGreaterThan(manager.significantChangeStarts, 0)
    }

    /// The latch. A when-in-use grant followed by an upgrade to always is two
    /// callbacks for one decision, and restarting services on the second would
    /// tear down everything the first set up.
    func test_secondAuthorizedCallback_doesNotRestartServices() {
        trackingEnable = true
        manager.stubbedAuthorizationStatus = .authorizedWhenInUse
        service.locationManager(manager, didChangeAuthorization: .authorizedWhenInUse)
        let afterFirst = manager.significantChangeStarts

        manager.stubbedAuthorizationStatus = .authorizedAlways
        service.locationManager(manager, didChangeAuthorization: .authorizedAlways)

        XCTAssertEqual(manager.significantChangeStarts, afterFirst,
                       "the upgrade must not restart what the first grant started")
    }

    /// An integrator who has not called `startTracking` gets nothing started on
    /// their behalf, however the authorization lands.
    func test_servicesDoNotStartWhenTrackingIsDisabled() {
        trackingEnable = false
        manager.stubbedAuthorizationStatus = .authorizedAlways

        service.locationManager(manager, didChangeAuthorization: .authorizedAlways)

        XCTAssertEqual(manager.significantChangeStarts, 0)
    }

    /// A refusal is not a grant.
    func test_deniedCallbackStartsNothing() {
        trackingEnable = true
        manager.stubbedAuthorizationStatus = .denied

        service.locationManager(manager, didChangeAuthorization: .denied)

        XCTAssertEqual(manager.significantChangeStarts, 0)
    }
}

final class MaskedKeyTests: XCTestCase {

    /// `privacy: .private` redacts for readers outside the process, but an
    /// in-process `OSLogStore` read — how a host app exports its own diagnostics —
    /// sees straight through it, so the key travelled in every support bundle.
    /// Masking at source is what closes that.
    func test_maskedKey_keepsEnoughToIdentifyAndNotEnoughToUse() {
        let key = "7fe74f6e-30c7-4430-ba80-2c322140e5b3"
        let masked = woosmapMaskedKey(key)

        XCTAssertEqual(masked, "7fe7…e5b3")
        XCTAssertFalse(masked.contains(key))
        XCTAssertLessThan(masked.count, key.count)
    }

    /// Two keys with a shared prefix still read differently, which is the point of
    /// keeping any characters at all.
    func test_maskedKey_distinguishesTwoKeys() {
        XCTAssertNotEqual(woosmapMaskedKey("7fe74f6e-aaaa-0000-0000-000000000001"),
                          woosmapMaskedKey("7fe74f6e-aaaa-0000-0000-000000000002"))
    }

    /// A short string could be revealed entirely by a prefix/suffix, so it is not
    /// shown at all. Empty is reported as empty, which is a configuration error
    /// worth seeing.
    func test_maskedKey_revealsNothingWhenTooShort() {
        XCTAssertEqual(woosmapMaskedKey(""), "(empty)")
        XCTAssertEqual(woosmapMaskedKey("abc123"), "(set)")
    }

    /// The gap the threshold closes: eight revealed characters are a fifth of a
    /// real 36-character key, but two thirds of a 12-character one. Anything that
    /// short is withheld entirely rather than mostly handed over.
    func test_maskedKey_withholdsAKeyShortEnoughToBeMostlyRevealed() {
        XCTAssertEqual(woosmapMaskedKey("abcdefghijkl"), "(set)", "12 characters is under the minimum")
        XCTAssertEqual(woosmapMaskedKey(String(repeating: "a", count: 19)), "(set)")
        XCTAssertEqual(woosmapMaskedKey(String(repeating: "a", count: 20)), "aaaa…aaaa",
                       "at the minimum, eight of twenty is a proportion worth trading for identifiability")
    }
}

final class VisitGuardTests: XCTestCase, VisitServiceDelegate {

    private var received: [Visit] = []
    func processVisit(visit: Visit) { received.append(visit) }

    private var manager: FakeLocationManager!
    private var service: LocationServiceCoreImpl!

    override func setUp() {
        super.setUp()
        received = []
        Visits.deleteAll()
        manager = FakeLocationManager()
        service = LocationServiceCoreImpl(locationManger: manager)
        accuracyVisitFilter = 50.0
    }

    override func tearDown() {
        Visits.deleteAll()
        accuracyVisitFilter = 50.0
        service = nil
        manager = nil
        super.tearDown()
    }

    /// Nothing is listening, so nothing is recorded — and the trace line added with
    /// the guard is what says so, rather than the silence that used to.
    func test_visitWithNoDelegate_isDropped() {
        service.visitDelegate = nil
        service.updateVisit(visit: FakeVisit(accuracy: 10))
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(Visits.getAll().count, 0)
    }

    /// The filter is a floor on confidence: a visit less accurate than the
    /// threshold says little about where the user actually was.
    func test_visitLessAccurateThanTheFilter_isDropped() {
        service.visitDelegate = self
        accuracyVisitFilter = 50.0
        service.updateVisit(visit: FakeVisit(accuracy: 80))
        XCTAssertTrue(received.isEmpty)
    }

    /// The boundary is exclusive: equal to the filter is not better than it.
    func test_visitExactlyAtTheFilter_isDropped() {
        service.visitDelegate = self
        accuracyVisitFilter = 50.0
        service.updateVisit(visit: FakeVisit(accuracy: 50))
        XCTAssertTrue(received.isEmpty)
    }
}

/// `CLVisit` has no public initialiser, so accuracy is the only property a test
/// can vary — which is the one the guard reads.
private final class FakeVisit: CLVisit {
    private let accuracy: CLLocationAccuracy
    init(accuracy: CLLocationAccuracy) {
        self.accuracy = accuracy
        super.init()
    }
    required init?(coder: NSCoder) { fatalError("unused") }
    override var horizontalAccuracy: CLLocationAccuracy { accuracy }
}
