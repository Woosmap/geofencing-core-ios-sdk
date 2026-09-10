//
//  CLMonitorBackendTests.swift
//  WoosmapGeofencingCoreTests
//
//  Covers the CLMonitor backend's own logic, which until now was only exercised
//  from the consuming SDK's test target. Core ships separately — its own podspec
//  and SPM package — so it has to stand up on its own.
//
//  A real `CLMonitor` cannot be driven from a test: it is a system service, its
//  events arrive only from actual location changes, and `CLMonitor.Event` has no
//  public initialiser. What is testable is everything around that — the seeded
//  assumption per condition kind, the state decision, and the synchronous mirror
//  the seam depends on.
//
//  Copyright © 2026 Web Geo Services. All rights reserved.
//

import XCTest
import CoreLocation
@testable import WoosmapGeofencingCore

//
//  Note on availability: the class is deliberately *not* marked
//  `@available(iOS 17.0, *)`. XCTest discovers tests through the Objective-C
//  runtime, which ignores Swift availability, so an annotated class still runs on
//  iOS 16 — and then crashes the moment it touches `CLMonitor`. Every test carries
//  a runtime guard instead, which both skips cleanly and satisfies the compiler.
//
final class CLMonitorBackendTests: XCTestCase {

    private let anchor = CLLocationCoordinate2D(latitude: 43.6053862, longitude: 3.8793329)

    /// A distinct monitor name per test: CoreLocation permits one open `CLMonitor`
    /// per name per process, and the name also keys a persisted condition store.
    private func uniqueName(_ label: String) -> String {
        "WoosmapCoreTest\(label)\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))"
    }

    // MARK: - Seeded assumption

    /// `RegionsGenerator` centres the `_radius` rings on the fix that produced
    /// them, so the user is inside by construction. Seeding `.unsatisfied` would
    /// make all five fire an enter nobody walked, on every location update.
    func test_concentricRings_areSeededSatisfied() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        for radius in [200.0, 300.0, 500.0, 1000.0, 2000.0] {
            let identifier = "\(RegionType.position.rawValue)_radius \(radius)"
            XCTAssertEqual(MonitorSession.assumedState(for: identifier), .satisfied, identifier)
        }
    }

    /// The translations sit at least 270 m from the user with a ~140 m radius, so
    /// outside is equally certain.
    func test_gridTranslations_areSeededUnsatisfied() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        for suffix in ["_translation n", "_translation nw", "_translation ne",
                       "_translation s", "_translation sw", "_translation se",
                       // Not a typo here: `RegionGenerator.swift` really builds
                       // this one without the leading underscore, and has since
                       // 2022. The test mirrors the identifier the SDK ships.
                       "translation e", "_translation w"] {
            let identifier = RegionType.position.rawValue + suffix
            XCTAssertEqual(MonitorSession.assumedState(for: identifier), .unsatisfied, identifier)
        }
    }

    /// Assuming outside is what lets a genuine "already inside" enter arrive as an
    /// initial determination rather than being pre-empted.
    func test_poiAndCustomGeofences_areSeededUnsatisfied() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        XCTAssertEqual(MonitorSession.assumedState(for: "poi<id>store-A<id>"), .unsatisfied)
        XCTAssertEqual(MonitorSession.assumedState(for: "custom<id>my-zone"), .unsatisfied)
    }

    /// The check is a prefix match on the whole identifier, so a POI whose store id
    /// merely contains the ring prefix is not mistaken for a ring.
    func test_aPOIContainingTheRingPrefix_isNotSeededSatisfied() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        XCTAssertEqual(MonitorSession.assumedState(for: "poi<id>position_radius 200.0<id>"),
                       .unsatisfied)
    }

    // MARK: - State decision

    func test_firstStateForAnIdentifier_isAnInitialDetermination() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let session = MonitorSession.shared(named: uniqueName("First"))

        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .satisfied, eventDate: Date()),
                       .transition(didEnter: true, isInitial: true))
    }

    func test_aLaterFlip_isACrossingNotAnInitialDetermination() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let session = MonitorSession.shared(named: uniqueName("Flip"))
        let base = Date()
        _ = session.decide(identifier: "poi<id>a<id>", state: .unsatisfied, eventDate: base)

        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .satisfied,
                                      eventDate: base.addingTimeInterval(10)),
                       .transition(didEnter: true, isInitial: false))
    }

    /// CoreLocation has been observed handing one event to the stream twice,
    /// milliseconds apart, with an identical date and state.
    func test_theSameDeliveryTwice_isSuppressed() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let session = MonitorSession.shared(named: uniqueName("Dup"))
        let eventDate = Date(), arrival = Date()
        _ = session.decide(identifier: "poi<id>a<id>", state: .satisfied,
                           eventDate: eventDate, now: arrival)

        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .satisfied,
                                      eventDate: eventDate,
                                      now: arrival.addingTimeInterval(0.018)),
                       .duplicate)
    }

    /// A genuine later crossing carries a later date, so it survives the window.
    func test_aLaterCrossingInsideTheWindow_survives() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let session = MonitorSession.shared(named: uniqueName("Window"))
        let eventDate = Date(), arrival = Date()
        _ = session.decide(identifier: "poi<id>a<id>", state: .satisfied,
                           eventDate: eventDate, now: arrival)

        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .unsatisfied,
                                      eventDate: eventDate.addingTimeInterval(1),
                                      now: arrival.addingTimeInterval(1)),
                       .transition(didEnter: false, isInitial: false))
    }

    /// `.unknown` is a gap in knowledge, not a removal, so the last known state is
    /// kept and a following flip is still a crossing.
    func test_unknown_reportsNothingAndKeepsTheLastKnownState() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let session = MonitorSession.shared(named: uniqueName("Unknown"))
        let base = Date()
        _ = session.decide(identifier: "poi<id>a<id>", state: .unsatisfied, eventDate: base)

        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .unknown,
                                      eventDate: base.addingTimeInterval(1)),
                       .undetermined)
        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .satisfied,
                                      eventDate: base.addingTimeInterval(2)),
                       .transition(didEnter: true, isInitial: false))
    }

    /// `.unmonitored` must forget the identifier. Recording it would resurrect
    /// state that `remove()` had just cleared, and a re-add — which nearest-N churn
    /// does constantly — would then report "already inside" as a crossing.
    func test_unmonitored_forgetsTheIdentifierSoAReAddIsInitialAgain() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip(".unmonitored requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("Forget"))
        let base = Date()

        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .unsatisfied, eventDate: base),
                       .transition(didEnter: false, isInitial: true))
        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .unmonitored,
                                      eventDate: base.addingTimeInterval(1)),
                       .forget)
        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .satisfied,
                                      eventDate: base.addingTimeInterval(2)),
                       .transition(didEnter: true, isInitial: true),
                       "a re-added condition reports its initial state again")
    }

    /// State is tracked per identifier, so one region's history cannot affect
    /// another's first report.
    func test_stateIsTrackedPerIdentifier() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let session = MonitorSession.shared(named: uniqueName("PerId"))
        let base = Date()
        _ = session.decide(identifier: "poi<id>a<id>", state: .satisfied, eventDate: base)

        XCTAssertEqual(session.decide(identifier: "poi<id>b<id>", state: .satisfied, eventDate: base),
                       .transition(didEnter: true, isInitial: true))
    }

    // MARK: - The synchronous mirror

    /// `CLMonitor` is async but the seam is not: reads answer from the mirror
    /// immediately rather than awaiting the platform.
    func test_startAndStop_areVisibleImmediately() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let backend = CLMonitorBackend(monitorName: uniqueName("Mirror"))

        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)

        XCTAssertEqual(backend.monitoredCircularIdentifiers, ["poi<id>store-A<id>"])
        let geofence = backend.monitoredGeofences.first
        XCTAssertEqual(geofence?.radius, 120)
        XCTAssertEqual(geofence?.center.latitude, anchor.latitude)

        backend.stop(identifier: "poi<id>store-A<id>")

        XCTAssertTrue(backend.monitoredGeofences.isEmpty)
    }

    func test_startingTheSameIdentifierTwice_replacesRatherThanDuplicates() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let backend = CLMonitorBackend(monitorName: uniqueName("Replace"))

        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 400)

        XCTAssertEqual(backend.monitoredGeofences.count, 1)
        XCTAssertEqual(backend.monitoredGeofences.first?.radius, 400)
    }

    func test_stop_forAnIdentifierItDoesNotHold_isANoOp() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let backend = CLMonitorBackend(monitorName: uniqueName("NoOp"))
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)

        backend.stop(identifier: "poi<id>beacon-1<id>")

        XCTAssertEqual(backend.monitoredCircularIdentifiers, ["poi<id>store-A<id>"])
    }

    /// `CLMonitor` reports a region's initial state once seeded, which is what
    /// stands the SDK's manual "already inside" check down.
    func test_theBackendDeclaresThatItReportsInitialState() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        XCTAssertTrue(CLMonitorBackend(monitorName: uniqueName("Flag")).reportsInitialState)
        XCTAssertFalse(LegacyRegionBackend(locationManager: { nil }).reportsInitialState)
    }

    /// The backend owns its event stream, so platform callbacks are discarded.
    func test_reportPlatformEvent_isIgnored() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let backend = CLMonitorBackend(monitorName: uniqueName("Ignore"))
        var received = 0
        backend.onTransition = { _ in received += 1 }

        backend.reportPlatformEvent(region: CLCircularRegion(center: anchor, radius: 100,
                                                             identifier: "poi<id>a<id>"),
                                    didEnter: true)

        XCTAssertEqual(received, 0, "CLMonitor drives its own events")
    }

    // MARK: - Publishing a transition

    /// `publish` is the step between `CLMonitor`'s event stream and the service.
    /// It was previously uncovered, and both defects found in review lived here.
    func test_publish_resolvesGeometryFromTheRegistry() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let backend = CLMonitorBackend(monitorName: uniqueName("Publish"))
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 250)

        let delivered = expectation(description: "transition delivered")
        var received: GeofenceTransition?
        backend.onTransition = { transition in
            received = transition
            delivered.fulfill()
        }

        backend.publish(identifier: "poi<id>store-A<id>", didEnter: true, isInitial: false)
        wait(for: [delivered], timeout: 2)

        XCTAssertEqual(received?.identifier, "poi<id>store-A<id>")
        XCTAssertEqual(received?.radius, 250)
        XCTAssertEqual(received?.center.latitude, anchor.latitude)
        XCTAssertEqual(received?.didEnter, true)
        XCTAssertEqual(received?.initialState, false)
    }

    /// The whole write path downstream of `onTransition` is main-queue work:
    /// `Regions.add` builds entities on `NSPersistentContainer.viewContext`, and
    /// the public region callbacks fired on main under the legacy delegate path.
    /// `CLMonitor`'s events arrive on the cooperative pool, so the hop matters.
    func test_publish_deliversOnTheMainQueue() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let backend = CLMonitorBackend(monitorName: uniqueName("MainQueue"))
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 100)

        let delivered = expectation(description: "transition delivered")
        var wasMain = false
        backend.onTransition = { _ in
            wasMain = Thread.isMainThread
            delivered.fulfill()
        }

        // Publish from a background queue, which is where `consume(from:)` runs.
        DispatchQueue.global().async {
            backend.publish(identifier: "poi<id>store-A<id>", didEnter: false, isInitial: false)
        }
        wait(for: [delivered], timeout: 2)

        XCTAssertTrue(wasMain, "delivery must land on the main queue")
    }

    /// A beacon condition shares the POI identifier scheme but is not circular,
    /// so it is in neither the registry nor the restored store.
    func test_publish_ignoresAnIdentifierNothingKnows() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("CLMonitor requires iOS 17") }
        let backend = CLMonitorBackend(monitorName: uniqueName("Unknown"))
        var received = 0
        backend.onTransition = { _ in received += 1 }

        backend.publish(identifier: "poi<id>never-registered<id>", didEnter: true, isInitial: true)

        // Nothing to wait for: with no geometry to resolve, `publish` returns
        // before it would ever schedule a delivery.
        XCTAssertEqual(received, 0)
    }
}
