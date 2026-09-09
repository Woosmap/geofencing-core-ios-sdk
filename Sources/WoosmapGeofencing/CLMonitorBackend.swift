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
        // Assume outside and let CoreLocation correct us.
        //
        // Adding with `.unknown` makes every new condition emit an event the
        // moment its state resolves — usually an exit the user never walked.
        // Assuming `.unsatisfied` costs nothing when it is right (silence, which
        // is what the legacy path produced for a region you are outside of) and
        // self-corrects when it is wrong: standing inside still yields a genuine
        // enter, which is exactly the "already inside" fire the SDK used to
        // synthesise via checkIfUserIsInRegion.
        await monitor.add(condition, identifier: identifier, assuming: .unsatisfied)
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
            if WoosLog.isValidLevel(level: .error) {
                if #available(iOS 14.0, *) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) CLMonitor event stream failed: \(error.localizedDescription)")
                } else {
                    WoosLog.error("CLMonitor event stream failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handle(_ event: CLMonitor.Event) {
        let identifier = event.identifier
        let now = Date()

        let isInitial: Bool? = stateLock.withLock {
            if let seen = lastHandled[identifier],
               seen.date == event.date,
               seen.state == event.state,
               now.timeIntervalSince(seen.receivedAt) < Self.duplicateWindow {
                return nil  // same delivery twice
            }
            lastHandled[identifier] = (event.date, event.state, now)
            let first = lastStates[identifier] == nil
            lastStates[identifier] = event.state
            return first
        }
        guard let isInitial else { return }

        let didEnter: Bool
        switch event.state {
        case .satisfied:   didEnter = true
        case .unsatisfied: didEnter = false
        default:
            // `.unknown`, and `.unmonitored` from iOS 17.2, are not crossings.
            return
        }

        let handlers = stateLock.withLock { Array(observers.values) }
        for handler in handlers {
            handler(identifier, didEnter, isInitial)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
