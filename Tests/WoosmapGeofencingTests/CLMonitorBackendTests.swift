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
//  `@available(iOS 17.2, *)`. XCTest discovers tests through the Objective-C
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

    /// Builds a backend and registers teardown that stops whatever it still holds.
    ///
    /// Each distinct monitor name keys its own persisted condition store on disk,
    /// so tests that add conditions and never remove them leave a store behind on
    /// every run. Going through here keeps that bounded.
    @available(iOS 17.2, *)
    private func makeBackend(_ label: String) -> CLMonitorBackend {
        let backend = CLMonitorBackend(monitorName: uniqueName(label))
        addTeardownBlock {
            for geofence in backend.monitoredGeofences {
                backend.stop(identifier: geofence.identifier)
            }
        }
        return backend
    }

    // MARK: - Seeded assumption

    /// `RegionsGenerator` centres the `_radius` rings on the fix that produced
    /// them, so the user is inside by construction. Seeding `.unsatisfied` would
    /// make all five fire an enter nobody walked, on every location update.
    func test_concentricRings_areSeededSatisfied() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        for radius in [200.0, 300.0, 500.0, 1000.0, 2000.0] {
            let identifier = "\(RegionType.position.rawValue)_radius \(radius)"
            XCTAssertEqual(MonitorSession.assumedState(for: identifier), .satisfied, identifier)
        }
    }

    /// The translations sit at least 270 m from the user with a ~140 m radius, so
    /// outside is equally certain.
    func test_gridTranslations_areSeededUnsatisfied() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
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

    /// A refresh is a remove followed by an add of the same region, which from the
    /// session's point of view is indistinguishable from a genuine removal. Dropping
    /// the remembered state there made every re-registered region's next event look
    /// like a first determination — the reason a field capture showed
    /// `fromPositionDetection = 1` on 26 of 28 events, including regions crossed
    /// five times.
    ///
    /// Driven through the pure retire/restore pair rather than `add`/`remove`, for
    /// the same reason `decide` exists: those open a real `CLMonitor` against a real
    /// on-disk store, which is slow and leaves state behind between runs.
    func test_refreshedGeofence_keepsItsLastState() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let fence = CircularGeofence(identifier: "poi<id>store-A<id>",
                                     center: CLLocationCoordinate2D(latitude: 43.6109, longitude: 3.8772),
                                     radius: 150)

        let carried = MonitorSession.stateCarriedAcrossRefresh(retired: (.satisfied, fence),
                                                               center: fence.center,
                                                               radius: fence.radius)

        XCTAssertEqual(carried, .satisfied,
                       "the same circle coming back is a refresh, not a new region")
    }

    /// A grid translation keeps its identifier while its centre moves with the user,
    /// so a state carried across that move would describe the wrong circle.
    func test_geofenceMovedToANewCentre_isTreatedAsNew() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let fence = CircularGeofence(identifier: "position_translation n",
                                     center: CLLocationCoordinate2D(latitude: 43.6109, longitude: 3.8772),
                                     radius: 140)

        let carried = MonitorSession.stateCarriedAcrossRefresh(
            retired: (.unsatisfied, fence),
            center: CLLocationCoordinate2D(latitude: 43.6200, longitude: 3.8900),
            radius: 140)

        XCTAssertNil(carried, "a circle somewhere else has no prior state to inherit")
    }

    /// Same centre, different radius — a POI whose configured radius changed. The
    /// circle is not the one the state described.
    func test_geofenceResized_isTreatedAsNew() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let fence = CircularGeofence(identifier: "poi<id>store-A<id>",
                                     center: CLLocationCoordinate2D(latitude: 43.6109, longitude: 3.8772),
                                     radius: 150)

        XCTAssertNil(MonitorSession.stateCarriedAcrossRefresh(retired: (.satisfied, fence),
                                                              center: fence.center,
                                                              radius: 300))
    }

    /// Assuming nothing is what lets a genuine "already inside" enter arrive: with
    /// `.unknown` CoreLocation resolves the real state and reports it, where a
    /// seeded guess would pre-empt the determination.
    func test_poiAndCustomGeofences_areSeededUnknown() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        XCTAssertEqual(MonitorSession.assumedState(for: "poi<id>store-A<id>"), .unknown)
        XCTAssertEqual(MonitorSession.assumedState(for: "custom<id>my-zone"), .unknown)
    }

    /// The check is a prefix match on the whole identifier, so a POI whose store id
    /// merely contains the ring prefix is not mistaken for a ring.
    func test_aPOIContainingTheRingPrefix_isNotSeededSatisfied() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        XCTAssertEqual(MonitorSession.assumedState(for: "poi<id>position_radius 200.0<id>"),
                       .unknown,
                       "seeded as the POI it is, not as a grid cell")
    }

    // MARK: - State decision

    func test_firstStateForAnIdentifier_isAnInitialDetermination() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("First"))

        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .satisfied, eventDate: Date()),
                       .transition(didEnter: true, isInitial: true))
    }

    func test_aLaterFlip_isACrossingNotAnInitialDetermination() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
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
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
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
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
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
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
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
                       .forget(systemDropped: true),
                       "no removal of ours was outstanding, so CoreLocation dropped it on its own")
        XCTAssertEqual(session.decide(identifier: "poi<id>a<id>", state: .satisfied,
                                      eventDate: base.addingTimeInterval(2)),
                       .transition(didEnter: true, isInitial: true),
                       "a re-added condition reports its initial state again")
    }

    /// State is tracked per identifier, so one region's history cannot affect
    /// another's first report.
    func test_stateIsTrackedPerIdentifier() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
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
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let backend = makeBackend("Mirror")

        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)

        XCTAssertEqual(backend.monitoredCircularIdentifiers, ["poi<id>store-A<id>"])
        let geofence = backend.monitoredGeofences.first
        XCTAssertEqual(geofence?.radius, 120)
        XCTAssertEqual(geofence?.center.latitude, anchor.latitude)

        backend.stop(identifier: "poi<id>store-A<id>")

        XCTAssertTrue(backend.monitoredGeofences.isEmpty)
    }

    func test_startingTheSameIdentifierTwice_replacesRatherThanDuplicates() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let backend = makeBackend("Replace")

        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 400)

        XCTAssertEqual(backend.monitoredGeofences.count, 1)
        XCTAssertEqual(backend.monitoredGeofences.first?.radius, 400)
    }

    func test_stop_forAnIdentifierItDoesNotHold_isANoOp() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let backend = makeBackend("NoOp")
        backend.start(identifier: "poi<id>store-A<id>", center: anchor, radius: 120)

        backend.stop(identifier: "poi<id>beacon-1<id>")

        XCTAssertEqual(backend.monitoredCircularIdentifiers, ["poi<id>store-A<id>"])
    }

    /// `CLMonitor` reports a region's initial state once seeded, which is what
    /// stands the SDK's manual "already inside" check down.
    func test_theBackendDeclaresThatItReportsInitialState() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        XCTAssertTrue(makeBackend("Flag").reportsInitialState)
        XCTAssertFalse(LegacyRegionBackend(locationManager: { nil }).reportsInitialState)
    }

    /// The backend owns its event stream, so platform callbacks are discarded.
    func test_reportPlatformEvent_isIgnored() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let backend = makeBackend("Ignore")
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
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let backend = makeBackend("Publish")
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
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let backend = makeBackend("MainQueue")
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
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let backend = makeBackend("Unknown")
        var received = 0

        // Inverted rather than a plain assertion: `publish` delivers via
        // `DispatchQueue.main.async`, so checking a counter synchronously would
        // pass even if the identifier *were* wrongly resolved — the delivery
        // could not have run yet. This fails if anything arrives.
        let nothingDelivered = expectation(description: "no transition delivered")
        nothingDelivered.isInverted = true
        backend.onTransition = { _ in
            received += 1
            nothingDelivered.fulfill()
        }

        backend.publish(identifier: "poi<id>never-registered<id>", didEnter: true, isInitial: true)

        wait(for: [nothingDelivered], timeout: 0.5)
        XCTAssertEqual(received, 0)
    }

    // MARK: - Registration seeding

    /// The regression this guards: a condition whose assumption CoreLocation
    /// agrees with never produces an event, so `lastStates` stayed empty and the
    /// *next* event — a real crossing — read as a first determination. With the
    /// `initialState` gate in `handle(transition:)` that silently dropped the grid
    /// wake-up, which is the whole reason the call is wired.
    func test_concentricRingIsSeededSoWalkingOutReadsAsACrossing() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("SeedRing"))
        let ring = "position_radius200"
        XCTAssertEqual(MonitorSession.assumedState(for: ring), .satisfied,
                       "precondition: rings are seeded satisfied and so stay silent")

        session.recordRegistration(identifier: ring, center: anchor, radius: 200,
                                   assuming: MonitorSession.assumedState(for: ring))

        XCTAssertEqual(session.decide(identifier: ring, state: .unsatisfied, eventDate: Date()),
                       .transition(didEnter: false, isInitial: false),
                       "leaving a ring is a crossing, not a first determination")
    }

    /// Mirror image: translation cells are seeded `.unsatisfied`, so the silent
    /// case is entry rather than exit.
    func test_gridTranslationIsSeededSoWalkingInReadsAsACrossing() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("SeedGrid"))
        let cell = "position<id>ne<id>"
        XCTAssertEqual(MonitorSession.assumedState(for: cell), .unsatisfied)

        session.recordRegistration(identifier: cell, center: anchor, radius: 140,
                                   assuming: MonitorSession.assumedState(for: cell))

        XCTAssertEqual(session.decide(identifier: cell, state: .satisfied, eventDate: Date()),
                       .transition(didEnter: true, isInitial: false))
    }

    /// `.unknown` must stay unseeded. It asserts nothing, always produces an
    /// event, and that event genuinely is the first determination — which is what
    /// POI and custom circles rely on to learn whether the user is already inside.
    func test_poiIsNotSeededSoItsFirstEventIsStillAnInitialDetermination() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("SeedPOI"))
        let poi = "poi<id>bakery<id>"
        XCTAssertEqual(MonitorSession.assumedState(for: poi), .unknown)

        session.recordRegistration(identifier: poi, center: anchor, radius: 150,
                                   assuming: MonitorSession.assumedState(for: poi))

        XCTAssertEqual(session.decide(identifier: poi, state: .satisfied, eventDate: Date()),
                       .transition(didEnter: true, isInitial: true))
    }

    /// A state carried across a refresh describes what CoreLocation actually
    /// resolved; the seed is only what we assumed. The restored one wins.
    func test_restoredStateOutranksTheRegistrationSeed() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("SeedRestore"))
        let ring = "position_radius200"

        session.recordRegistration(identifier: ring, center: anchor, radius: 200,
                                   assuming: MonitorSession.assumedState(for: ring))
        // The user leaves, so the resolved state disagrees with the seed.
        _ = session.decide(identifier: ring, state: .unsatisfied, eventDate: Date())
        // A refresh: `stop` retires the state, the identical circle comes back.
        session.forget(identifier: ring)
        session.recordRegistration(identifier: ring, center: anchor, radius: 200,
                                   assuming: MonitorSession.assumedState(for: ring))

        XCTAssertEqual(session.decide(identifier: ring, state: .satisfied,
                                      eventDate: Date().addingTimeInterval(1)),
                       .transition(didEnter: true, isInitial: false),
                       "re-entering is a crossing: the restored .unsatisfied must beat the .satisfied seed")
    }

    func test_seedIsDeterminateOnlyForResolvedStates() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        XCTAssertTrue(MonitorSession.seedIsDeterminate(.satisfied))
        XCTAssertTrue(MonitorSession.seedIsDeterminate(.unsatisfied))
        XCTAssertFalse(MonitorSession.seedIsDeterminate(.unknown))
        XCTAssertFalse(MonitorSession.seedIsDeterminate(.unmonitored))
    }

    // MARK: - Conditions CoreLocation drops by itself

    /// Before iOS 18 the event carries no reason, so a dropped condition was
    /// logged as "expected after remove" and left in the mirror. Past the
    /// active-monitoring cap that makes `monitoredGeofences` claim conditions
    /// CoreLocation no longer holds, which the custom-region budget reads.
    func test_unmonitoredForAStillRegisteredConditionIsASystemDrop() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("Dropped"))
        let poi = "poi<id>dropped<id>"
        session.recordRegistration(identifier: poi, center: anchor, radius: 150,
                                   assuming: MonitorSession.assumedState(for: poi))

        XCTAssertEqual(session.decide(identifier: poi, state: .unmonitored, eventDate: Date()),
                       .forget(systemDropped: true),
                       "we never asked for this removal: the mirror still held the condition")
        XCTAssertFalse(session.knownGeofences().contains { $0.identifier == poi },
                       "a condition CoreLocation let go must not stay in the mirror")
    }

    /// The counterpart: `stop` clears the mirror synchronously through `forget`,
    /// before `remove` is even enqueued, so our own removals stay routine.
    func test_unmonitoredAfterOurOwnStopIsNotASystemDrop() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("OurStop"))
        let poi = "poi<id>ours<id>"
        session.recordRegistration(identifier: poi, center: anchor, radius: 150,
                                   assuming: MonitorSession.assumedState(for: poi))
        // What `stop` does: clear the mirror, then record that a remove is queued.
        session.forget(identifier: poi)
        session.expectRemovalAck(poi)

        XCTAssertEqual(session.decide(identifier: poi, state: .unmonitored, eventDate: Date()),
                       .forget(systemDropped: false))
    }

    // MARK: - Retired-state eviction

    /// The bound always held; the policy did not. Eviction walked a
    /// `Dictionary`'s keys, whose order is arbitrary, so it could drop a state a
    /// refresh was about to claim and keep one retired long ago.
    ///
    /// POI identifiers are the probe because they are assumed `.unknown` and so
    /// are never seeded at registration — whether their last state comes back is
    /// then entirely down to the retirement store.
    func test_retiredStateEvictionDropsTheOldestFirst() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("Evict"))
        let total = 65  // one past `retiredLimit`
        func identifier(_ index: Int) -> String { "poi<id>evict\(index)<id>" }

        func registerResolveAndRetire(_ id: String) {
            session.recordRegistration(identifier: id, center: anchor, radius: 100,
                                       assuming: MonitorSession.assumedState(for: id))
            _ = session.decide(identifier: id, state: .satisfied, eventDate: Date())
            session.forget(identifier: id)
        }

        for index in 0..<total {
            registerResolveAndRetire(identifier(index))
        }

        let oldest = identifier(0)
        session.recordRegistration(identifier: oldest, center: anchor, radius: 100,
                                   assuming: MonitorSession.assumedState(for: oldest))
        XCTAssertEqual(session.decide(identifier: oldest, state: .satisfied, eventDate: Date()),
                       .transition(didEnter: true, isInitial: true),
                       "the oldest retirement is the one the bound should have dropped")

        // Probed with the *opposite* state. Each identifier was retired at
        // `.satisfied`, and an unchanged state now stands down rather than reporting a
        // crossing — so feeding `.satisfied` here could no longer tell a restored state
        // from an evicted one. `.unsatisfied` distinguishes them: restored gives a
        // crossing against the remembered `.satisfied`, evicted gives a first
        // determination.
        let newest = identifier(total - 1)
        session.recordRegistration(identifier: newest, center: anchor, radius: 100,
                                   assuming: MonitorSession.assumedState(for: newest))
        XCTAssertEqual(session.decide(identifier: newest, state: .unsatisfied, eventDate: Date()),
                       .transition(didEnter: false, isInitial: false),
                       "the most recent retirement must survive to be claimed by its refresh")
    }

    // MARK: - Recovering a store that was locked at open

    private func fence(_ identifier: String, radius: CLLocationDistance = 100) -> CircularGeofence {
        CircularGeofence(identifier: identifier, center: anchor, radius: radius)
    }

    /// The case the unlock observer exists for, and the one it used to miss.
    ///
    /// `persisted` is filled by `restoredConditions` at open. If protected data was
    /// unavailable then, `record(for:)` yields nothing and the mirror is empty — so a
    /// reconcile that only walked the mirror had nothing to walk. Custom geofences are
    /// the real loss, since nothing else re-derives them, and `publish` drops every
    /// event for a condition whose geometry it cannot resolve.
    func test_mergeRecovered_fillsAMirrorThatWasEmptyAtOpen() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        var persisted: [String: CircularGeofence] = [:]
        var states: [String: CLMonitor.Event.State] = [:]
        let recovered = (geofences: ["custom<id>my-zone": fence("custom<id>my-zone"),
                                     "poi<id>store-A<id>": fence("poi<id>store-A<id>")],
                         states: ["custom<id>my-zone": CLMonitor.Event.State.satisfied])

        let regained = MonitorSession.mergeRecovered(recovered, into: &persisted, states: &states)

        XCTAssertEqual(Set(regained), ["custom<id>my-zone", "poi<id>store-A<id>"])
        XCTAssertEqual(persisted.count, 2)
        XCTAssertEqual(states["custom<id>my-zone"], .satisfied)
    }

    /// A re-read is never more current than what this process already holds, so it
    /// fills gaps and nothing else. Overwriting would discard a registration made since
    /// the open, and a `lastStates` entry written by an event that has already arrived.
    func test_mergeRecovered_doesNotOverwriteWhatTheProcessAlreadyKnows() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        var persisted = ["custom<id>my-zone": fence("custom<id>my-zone", radius: 250)]
        var states: [String: CLMonitor.Event.State] = ["custom<id>my-zone": .unsatisfied]
        let recovered = (geofences: ["custom<id>my-zone": fence("custom<id>my-zone", radius: 100)],
                         states: ["custom<id>my-zone": CLMonitor.Event.State.satisfied])

        let regained = MonitorSession.mergeRecovered(recovered, into: &persisted, states: &states)

        XCTAssertTrue(regained.isEmpty, "nothing was missing, so nothing was regained")
        XCTAssertEqual(persisted["custom<id>my-zone"]?.radius, 250, "the live registration wins")
        XCTAssertEqual(states["custom<id>my-zone"], .unsatisfied, "a state seen since the open wins")
    }

    /// A refresh is `stop` then `start` of one identifier, and the acknowledgement for
    /// the stop arrives on the event stream — so it can land after the re-registration.
    ///
    /// Deciding "system drop" by whether the mirror still holds the identifier called
    /// that a drop, and then evicted a live condition: `publish` could no longer resolve
    /// its geometry, so every real crossing was discarded, and it vanished from
    /// `monitoredGeofences` so the sweeps could not stop it either. The position grid
    /// does this for 13 identifiers on every location update.
    func test_lateRemovalAck_doesNotEvictAConditionThatWasReRegistered() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("LateAck"))
        let identifier = "position_translation ne"
        let assumed = MonitorSession.assumedState(for: identifier)

        session.recordRegistration(identifier: identifier, center: anchor, radius: 140,
                                   assuming: assumed)
        _ = session.decide(identifier: identifier, state: .satisfied, eventDate: Date())
        // What `stop` does: clear the mirror, then record that a remove is queued.
        session.forget(identifier: identifier)
        session.expectRemovalAck(identifier)
        session.recordRegistration(identifier: identifier, center: anchor, radius: 140,
                                   assuming: assumed)

        // The acknowledgement for the *first* registration, arriving late.
        XCTAssertEqual(session.decide(identifier: identifier, state: .unmonitored,
                                      eventDate: Date().addingTimeInterval(1)),
                       .undetermined,
                       "it acknowledges a registration we already replaced")
        XCTAssertTrue(session.knownGeofences().contains { $0.identifier == identifier },
                      "the live condition must stay in the mirror")

        XCTAssertEqual(session.decide(identifier: identifier, state: .unsatisfied,
                                      eventDate: Date().addingTimeInterval(2)),
                       .transition(didEnter: false, isInitial: false),
                       "and its next event is still a crossing, not a first determination")
    }

    /// The counterpart: with no removal of ours outstanding, an `.unmonitored` is
    /// CoreLocation dropping the condition by itself and the mirror must let it go.
    func test_unsolicitedUnmonitored_isStillASystemDrop() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("Unsolicited"))
        let identifier = "poi<id>dropped<id>"
        session.recordRegistration(identifier: identifier, center: anchor, radius: 150,
                                   assuming: MonitorSession.assumedState(for: identifier))

        XCTAssertEqual(session.decide(identifier: identifier, state: .unmonitored,
                                      eventDate: Date()),
                       .forget(systemDropped: true))
        XCTAssertFalse(session.knownGeofences().contains { $0.identifier == identifier })
    }

    /// CoreLocation has been observed delivering one event twice. The acknowledgement
    /// count is consumed by the first delivery, so without a duplicate marker the
    /// second looked unsolicited and evicted the condition that had just been
    /// re-registered — the exact failure the count exists to prevent, reachable by one
    /// repeated event.
    func test_repeatedRemovalAck_isDeduplicatedRatherThanTreatedAsASystemDrop() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("DupAck"))
        let identifier = "position_translation nw"
        let assumed = MonitorSession.assumedState(for: identifier)
        let acked = Date()

        session.recordRegistration(identifier: identifier, center: anchor, radius: 140,
                                   assuming: assumed)
        session.expectRemovalAck(identifier)
        session.recordRegistration(identifier: identifier, center: anchor, radius: 140,
                                   assuming: assumed)

        XCTAssertEqual(session.decide(identifier: identifier, state: .unmonitored, eventDate: acked),
                       .undetermined)
        XCTAssertEqual(session.decide(identifier: identifier, state: .unmonitored, eventDate: acked),
                       .duplicate,
                       "the repeat is the same delivery, not CoreLocation dropping it")
        XCTAssertTrue(session.knownGeofences().contains { $0.identifier == identifier },
                      "and the live condition survives both deliveries")
    }

    /// An acknowledgement expected for an identifier the mirror never held must still
    /// be honoured.
    ///
    /// `start` writes the backend registry synchronously while `recordRegistration`
    /// reaches `persisted` later on the chain, so a `start`/`stop`/`start` inside that
    /// window enqueues a real `remove` for something `forget` never saw. Counting on
    /// "the mirror held it" missed those, and the later acknowledgement evicted the
    /// second registration.
    ///
    /// This covers the bookkeeping, not the wiring: it calls `expectRemovalAck`
    /// directly, so it passes whether or not `stop` remembers to. Driving `stop` itself
    /// would need the enqueued `add` to be guaranteed not to have landed yet, which the
    /// chain gives no way to arrange — so that one line is covered by inspection.
    func test_expectedRemovalAckIsHonouredEvenIfTheMirrorNeverHeldIt() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("EarlyStop"))
        let identifier = "poi<id>early<id>"

        // stop() ran before the first add reached `persisted`: nothing to forget, but a
        // remove was still queued.
        XCTAssertFalse(session.forget(identifier: identifier),
                       "precondition: the mirror does not hold it yet")
        session.expectRemovalAck(identifier)

        // The second add lands, then the first remove is acknowledged.
        session.recordRegistration(identifier: identifier, center: anchor, radius: 150,
                                   assuming: MonitorSession.assumedState(for: identifier))

        XCTAssertEqual(session.decide(identifier: identifier, state: .unmonitored, eventDate: Date()),
                       .undetermined)
        XCTAssertTrue(session.knownGeofences().contains { $0.identifier == identifier },
                      "the live registration must not be evicted by the earlier remove")
    }

    /// An unchanged refresh must report nothing.
    ///
    /// POI and custom conditions are seeded `.unknown`, so CoreLocation resolves and
    /// reports them again on every re-registration. `forget` retires the prior state and
    /// `recordRegistration` restores it for identical geometry — so asking only whether
    /// a last state *exists* called the re-report a crossing. The gate in
    /// `handle(transition:)` then let it through, and a stationary refresh ran a full
    /// teardown and restart of every monitored region.
    func test_unchangedStateAcrossARefresh_reportsNothing() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("Unchanged"))
        let poi = "poi<id>stationary<id>"
        let assumed = MonitorSession.assumedState(for: poi)

        session.recordRegistration(identifier: poi, center: anchor, radius: 150, assuming: assumed)
        XCTAssertEqual(session.decide(identifier: poi, state: .satisfied, eventDate: Date()),
                       .transition(didEnter: true, isInitial: true),
                       "the first determination still reports the user is inside")

        // A refresh: same identifier, same circle, user has not moved.
        session.forget(identifier: poi)
        session.expectRemovalAck(poi)
        session.recordRegistration(identifier: poi, center: anchor, radius: 150, assuming: assumed)

        XCTAssertEqual(session.decide(identifier: poi, state: .satisfied,
                                      eventDate: Date().addingTimeInterval(60)),
                       .undetermined,
                       "nothing changed, so nothing is reported and no restart is triggered")

        // And a genuine crossing afterwards still reports.
        XCTAssertEqual(session.decide(identifier: poi, state: .unsatisfied,
                                      eventDate: Date().addingTimeInterval(120)),
                       .transition(didEnter: false, isInitial: false),
                       "leaving is still a crossing")
    }

    // MARK: - Teardown

    /// `stopTracking()` must let go of conditions restored from a previous process, not
    /// only the ones this process registered.
    ///
    /// The mirror is filled asynchronously by the `open()` that `init` enqueues, so a
    /// cold launch followed promptly by a stop reached the old teardown — a loop over
    /// the listing — with nothing in it. It stopped nothing, and the restore then
    /// brought those conditions back, still live and still waking the app after the
    /// integrator had disabled tracking.
    ///
    /// This covers the bookkeeping. The ordering itself — that `stopAll` is queued
    /// behind `open()` rather than racing it — is a property of the one FIFO chain and
    /// is covered by inspection: reproducing the race would need the restore held open,
    /// which the chain gives no way to arrange.
    func test_forgetAll_dropsRestoredConditionsAsWellAsRegisteredOnes() throws {
        guard #available(iOS 17.2, *) else { throw XCTSkip("CLMonitor requires iOS 17.2") }
        let session = MonitorSession.shared(named: uniqueName("TearDown"))
        let restored = "custom<id>from-a-previous-launch"
        let registered = "poi<id>this-launch<id>"

        for identifier in [restored, registered] {
            session.recordRegistration(identifier: identifier, center: anchor, radius: 150,
                                       assuming: MonitorSession.assumedState(for: identifier))
        }
        _ = session.decide(identifier: registered, state: .satisfied, eventDate: Date())

        let dropped = session.forgetAll()

        XCTAssertEqual(Set(dropped), [restored, registered])
        XCTAssertTrue(session.knownGeofences().isEmpty, "the mirror keeps nothing back")
        XCTAssertEqual(session.decide(identifier: registered, state: .satisfied, eventDate: Date()),
                       .transition(didEnter: true, isInitial: true),
                       "and no remembered state survives either")
    }
}
