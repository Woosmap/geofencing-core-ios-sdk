//
//  CLMonitorBackend.swift
//  WoosmapGeofencingCore
//
//  Circular-region monitoring on top of `CLMonitor`, which replaces the
//  soft-deprecated `CLCircularRegion` path on `CLLocationManager` from iOS 17.
//
//  Two properties of that API shape everything below:
//
//  1. `CLMonitor` is async throughout — opening it, adding and removing
//     conditions, and reading back what it monitors. `GeofenceMonitoringBackend`
//     is synchronous, and has to stay that way: its callers are the SDK's public
//     API. So this type keeps a synchronous mirror of what it has been asked to
//     monitor and applies the real work on a serial task chain behind it.
//  2. Events arrive on an `AsyncSequence` rather than a delegate, and
//     CoreLocation *stops monitoring* a condition when an event is pending for
//     it and no monitor has been opened to receive it. The consuming task
//     therefore starts as soon as the backend does and stays up for the life of
//     the process — the same constraint the delegate had, a different mechanism.
//

import Foundation
import CoreLocation
import os

/// What an incoming `CLMonitor` state means for a monitored identifier.
@available(iOS 17.0, *)
internal enum MonitorStateDecision: Equatable {
    /// The same delivery arrived twice — CoreLocation has been observed handing
    /// one event to the stream more than once, milliseconds apart.
    case duplicate
    /// A real transition. `isInitial` marks a determination rather than a crossing.
    case transition(didEnter: Bool, isInitial: Bool)
    /// The condition is no longer monitored; the identifier is now untracked.
    case forget
    /// State could not be determined; nothing to report and nothing forgotten.
    case undetermined
}

@available(iOS 17.0, *)
internal final class CLMonitorBackend: GeofenceMonitoringBackend {

    /// `CLMonitor` reports a region's initial state once seeded, so the SDK's
    /// own "already inside" check must stand down — see `MonitorSession.apply`.
    let reportsInitialState = true

    private let session: MonitorSession
    private let lock = NSLock()

    /// Mirror of the conditions this backend has been asked to monitor, so the
    /// synchronous reads can be answered without awaiting `CLMonitor`.
    private var registry: [String: CircularGeofence] = [:]

    /// Tail of the serial chain, so `start` and `stop` for one identifier are
    /// applied in the order they were requested. Bare `Task {}` would not
    /// guarantee that.
    private var pendingWork: Task<Void, Never>?

    private var transitionHandler: ((GeofenceTransition) -> Void)?

    var onTransition: ((GeofenceTransition) -> Void)? {
        get { lock.withLock { transitionHandler } }
        set { lock.withLock { transitionHandler = newValue } }
    }

    /// Identifies this backend's event subscription on the shared session.
    private let observerToken = UUID()

    init(monitorName: String = "WoosmapGeofencingConditions") {
        // Shared per name, because CoreLocation permits only one open CLMonitor
        // per name per process and throws
        // `NSInternalInconsistencyException("Monitor named … is already in use")`
        // on the second. The name also keys the persisted condition store, so it
        // cannot be made unique per instance without stranding conditions.
        session = MonitorSession.shared(named: monitorName)
        session.addObserver(observerToken) { [weak self] identifier, didEnter, isInitial in
            self?.publish(identifier: identifier, didEnter: didEnter, isInitial: isInitial)
        }
        enqueue { await $0.open() }
    }

    deinit {
        session.removeObserver(observerToken)
    }

    // MARK: - GeofenceMonitoringBackend

    var monitoredGeofences: [CircularGeofence] {
        lock.withLock { Array(registry.values) }
    }

    func start(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        lock.withLock {
            registry[identifier] = CircularGeofence(identifier: identifier, center: center, radius: radius)
        }
        enqueue { await $0.add(identifier: identifier, center: center, radius: radius) }
    }

    func stop(identifier: String) {
        let known = lock.withLock { registry.removeValue(forKey: identifier) != nil }
        // A beacon sharing this identifier is not in the registry, so it is left
        // alone — the same guarantee the legacy backend gives by type-checking.
        guard known else { return }
        enqueue { await $0.remove(identifier: identifier) }
    }

    /// Unused on this backend: `CLMonitor` owns its event stream, so nothing
    /// feeds it platform callbacks. Present only to satisfy the protocol, which
    /// the legacy backend needs because the service implements its delegate.
    func reportPlatformEvent(region: CLCircularRegion, didEnter: Bool) {}

    // MARK: - Internals

    /// Appends to the serial chain. Each unit of work awaits its predecessor, so
    /// ordering matches the call order even though `CLMonitor` is async.
    private func enqueue(_ work: @escaping @Sendable (MonitorSession) async -> Void) {
        lock.withLock {
            let previous = pendingWork
            let session = self.session
            pendingWork = Task {
                await previous?.value
                await work(session)
            }
        }
    }

    /// Resolves the geometry an event needs from the mirror, then hands the
    /// transition to the service.
    private func publish(identifier: String, didEnter: Bool, isInitial: Bool) {
        let geofence = lock.withLock { registry[identifier] }
        guard let geofence else { return }  // removed while the event was in flight
        let handler = lock.withLock { transitionHandler }
        handler?(GeofenceTransition(identifier: identifier,
                                    center: geofence.center,
                                    radius: geofence.radius,
                                    didEnter: didEnter,
                                    initialState: isInitial))
    }
}

/// Owns the `CLMonitor` and drains its events.
///
/// Separate from the backend because everything here is async and actor-isolated,
/// while the backend must present a synchronous face to the SDK.
@available(iOS 17.0, *)
internal final class MonitorSession: @unchecked Sendable {

    /// Names the on-disk condition store CoreLocation keeps for us. Changing it
    /// strands every condition already registered under the old name.
    ///
    /// Must be alphanumeric: `CLMonitor` throws
    /// `NSInternalInconsistencyException("Monitor name is not valid")` from its
    /// initialiser otherwise.
    private let monitorName: String

    private static let sessionsLock = NSLock()
    private static var sessions: [String: MonitorSession] = [:]

    /// The one session for this monitor name in this process.
    static func shared(named name: String) -> MonitorSession {
        sessionsLock.withLock {
            if let existing = sessions[name] { return existing }
            let created = MonitorSession(monitorName: name)
            sessions[name] = created
            return created
        }
    }

    /// Subscribers, keyed so each backend can detach on deinit.
    ///
    /// Events fan out to all of them; a backend ignores any identifier absent
    /// from its own registry, so sharing one session is safe.
    private var observers: [UUID: (String, Bool, Bool) -> Void] = [:]

    func addObserver(_ token: UUID, _ handler: @escaping (String, Bool, Bool) -> Void) {
        stateLock.withLock { observers[token] = handler }
    }

    func removeObserver(_ token: UUID) {
        stateLock.withLock { observers[token] = nil }
    }

    private var monitor: CLMonitor?
    private var eventTask: Task<Void, Never>?

    /// Memoises the open so concurrent callers await one construction.
    ///
    /// Backends each have their own serial work chain, so two of them can reach
    /// here at the same time. Without this, both would pass the `monitor == nil`
    /// check and both call `CLMonitor(name)` — the second throwing
    /// `NSInternalInconsistencyException("Monitor named … is already in use")`.
    private var openTask: Task<CLMonitor, Never>?

    /// Last state seen per identifier. Absence marks the next event as the
    /// initial determination rather than a crossing — `CLMonitor` does not
    /// distinguish the two for us.
    private var lastStates: [String: CLMonitor.Event.State] = [:]

    /// CoreLocation has been observed delivering one event twice, milliseconds
    /// apart, with an identical date and state. Both must match, and arrive
    /// inside this window, before anything is dropped: a later crossing carries
    /// a later date, so the date alone would do — the window is belt and braces.
    private var lastHandled: [String: (date: Date, state: CLMonitor.Event.State, receivedAt: Date)] = [:]
    private static let duplicateWindow: TimeInterval = 5

    private let stateLock = NSLock()

    private init(monitorName: String) {
        self.monitorName = monitorName
    }

    func open() async {
        _ = await activeMonitor()
    }

    func add(identifier: String, center: CLLocationCoordinate2D, radius: CLLocationDistance) async {
        let monitor = await activeMonitor()
        let condition = CLMonitor.CircularGeographicCondition(center: center, radius: radius)
        await monitor.add(condition,
                          identifier: identifier,
                          assuming: Self.assumedState(for: identifier))
    }

    /// Prefix of the position grid's concentric rings.
    ///
    /// `RegionsGenerator` centres these on the very fix that generated them, with
    /// radii from 200 m to 2 km, so the user is inside every one of them at the
    /// moment they are registered.
    private static let concentricRingPrefix = RegionType.position.rawValue + "_radius"

    /// The state a new condition is seeded with.
    ///
    /// Seeding matters because `CLMonitor` emits an event whenever the state it
    /// resolves differs from the assumption. Adding with `.unknown` therefore
    /// makes *every* new condition fire the moment it resolves.
    ///
    /// - The position grid's concentric rings are centred on the user, so
    ///   `.satisfied` is a certainty rather than a guess. Seeding `.unsatisfied`
    ///   there would make all five rings fire a bogus enter on every location
    ///   update, since the grid is torn down and rebuilt each time.
    /// - Everything else — POI circles, custom geofences, and the grid's
    ///   directional translations, which sit at least 270 m away from a ~140 m
    ///   circle — is assumed outside. That is silent when right, which is what
    ///   the legacy path produced for a region you are outside of, and
    ///   self-correcting when wrong: standing inside still yields a genuine
    ///   enter, which is exactly the "already inside" fire the SDK used to
    ///   synthesise via `checkIfUserIsInRegion`.
    internal static func assumedState(for identifier: String) -> CLMonitor.Event.State {
        identifier.hasPrefix(concentricRingPrefix) ? .satisfied : .unsatisfied
    }

    func remove(identifier: String) async {
        let monitor = await activeMonitor()
        await monitor.remove(identifier)
        stateLock.withLock {
            lastStates[identifier] = nil
            lastHandled[identifier] = nil
        }
    }

    /// Identifiers `CLMonitor` itself holds, as opposed to the backend's mirror.
    /// Used for reconciliation and diagnostics, not on the hot path.
    func registeredIdentifiers() async -> Set<String> {
        let monitor = await activeMonitor()
        return Set(await monitor.identifiers)
    }

    private func activeMonitor() async -> CLMonitor {
        if let existing = stateLock.withLock({ monitor }) { return existing }

        let task: Task<CLMonitor, Never> = stateLock.withLock {
            if let inFlight = openTask { return inFlight }
            let name = monitorName
            let created = Task { await CLMonitor(name) }
            openTask = created
            return created
        }
        let opened = await task.value

        return stateLock.withLock {
            // A concurrent caller may have installed it while we awaited.
            if let existing = monitor { return existing }
            monitor = opened
            // Draining must start now and stay up: CoreLocation stops monitoring
            // a condition when an event is pending for it and no monitor is open
            // to receive it.
            eventTask = Task { [weak self] in await self?.consume(from: opened) }
            return opened
        }
    }

    private func consume(from monitor: CLMonitor) async {
        do {
            for try await event in await monitor.events {
                handle(event)
            }
        } catch {
            // No `WoosLog` fallback, unlike the rest of the SDK: this type is
            // `@available(iOS 17, *)`, so `Logger` is always available here.
            if WoosLog.isValidLevel(level: .error) {
                Logger.sdklog.error("\(LogEvent.e.rawValue) CLMonitor event stream failed: \(error.localizedDescription)")
            }
        }
    }

    private func handle(_ event: CLMonitor.Event) {
        switch decide(identifier: event.identifier, state: event.state, eventDate: event.date) {
        case .duplicate, .undetermined:
            return
        case .forget:
            logStoppedMonitoring(event)
        case .transition(let didEnter, let isInitial):
            let handlers = stateLock.withLock { Array(observers.values) }
            for handler in handlers {
                handler(event.identifier, didEnter, isInitial)
            }
        }
    }

    /// Records `state` for `identifier` and says what it means.
    ///
    /// Split out of `handle(_:)` because `CLMonitor.Event` has no public
    /// initialiser: the event path itself cannot be reached from a test, so the
    /// logic lives here where it can be.
    internal func decide(identifier: String,
                         state: CLMonitor.Event.State,
                         eventDate: Date,
                         now: Date = Date()) -> MonitorStateDecision {
        stateLock.withLock {
            if let seen = lastHandled[identifier],
               seen.date == eventDate,
               seen.state == state,
               now.timeIntervalSince(seen.receivedAt) < Self.duplicateWindow {
                return .duplicate
            }

            switch state {
            case .satisfied, .unsatisfied:
                lastHandled[identifier] = (eventDate, state, now)
                let isInitial = lastStates[identifier] == nil
                lastStates[identifier] = state
                return .transition(didEnter: state == .satisfied, isInitial: isInitial)

            case .unknown:
                // State not yet resolved. Nothing to report, and the last known
                // state is deliberately kept: this is a gap in knowledge, not a
                // removal.
                return .undetermined

            default:
                // `.unmonitored`, iOS 17.2+. Normally CoreLocation acknowledging
                // our own `remove()`.
                //
                // The identifier is forgotten rather than recorded, for two
                // reasons. `remove()` clears this state, but the `.unmonitored`
                // event lands *after* it — recording it would resurrect the
                // entry, and then a later re-add would see a non-nil last state
                // and report the "already inside" enter as a crossing instead of
                // an initial determination. Nearest-N churn re-adds POIs
                // constantly, so that is a live path, not a corner case.
                // It also keeps these dictionaries bounded: the position grid
                // alone churns 13 identifiers on every location update.
                lastStates[identifier] = nil
                lastHandled[identifier] = nil
                return .forget
            }
        }
    }

    /// Records that CoreLocation stopped monitoring a condition.
    ///
    /// Routine when it is answering our own `remove()`. Not routine when it
    /// decided by itself — from iOS 18 the event carries the reason, which is the
    /// only way to see a condition limit or authorization problem now that there
    /// is no `monitoringDidFailFor` delegate callback.
    private func logStoppedMonitoring(_ event: CLMonitor.Event) {
        let reasons = Self.diagnosticReasons(for: event)
        guard WoosLog.isValidLevel(level: reasons == nil ? .trace : .warn) else { return }
        let detail = reasons.map { "CoreLocation stopped monitoring \(event.identifier): \($0)" }
            ?? "stopped monitoring \(event.identifier) (expected after remove)"
        // `Logger` unconditionally: see the note in `consume(from:)`.
        if reasons == nil {
            Logger.sdklog.trace("\(LogEvent.v.rawValue) \(detail)")
        } else {
            Logger.sdklog.warning("\(LogEvent.w.rawValue) \(detail)")
        }
    }

    /// Why CoreLocation stopped monitoring, when it says. `nil` means it gave no
    /// reason, which is what a removal we asked for looks like.
    private static func diagnosticReasons(for event: CLMonitor.Event) -> String? {
        guard #available(iOS 18.0, *) else { return nil }
        let flags = [
            ("authorizationDenied", event.authorizationDenied),
            ("authorizationDeniedGlobally", event.authorizationDeniedGlobally),
            ("authorizationRestricted", event.authorizationRestricted),
            ("insufficientlyInUse", event.insufficientlyInUse),
            ("accuracyLimited", event.accuracyLimited),
            ("conditionUnsupported", event.conditionUnsupported),
            ("conditionLimitExceeded", event.conditionLimitExceeded),
            ("persistenceUnavailable", event.persistenceUnavailable),
            ("serviceSessionRequired", event.serviceSessionRequired),
        ].filter { $0.1 }.map { $0.0 }
        return flags.isEmpty ? nil : flags.joined(separator: ",")
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
