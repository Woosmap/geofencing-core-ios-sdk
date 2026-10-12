//
//  ServiceSession.swift
//  WoosmapGeofencing
//
//  Holds the `CLServiceSession` that CoreLocation wants outstanding while an
//  app uses location in the background, and surfaces the diagnostics it
//  publishes.
//
//  Field logs from a device running the CLMonitor backend carried
//  `serviceSessionRequired` on events delivered after a background relaunch,
//  even without adopting the `CLRequireExplicitServiceSession` Info.plist key
//  that the header says makes that flag true. Holding a session settles it:
//  either the flag stops appearing, or it is reporting something undocumented,
//  and the diagnostics stream says which.
//
//  The Info.plist key is deliberately *not* adopted. It makes location services
//  conditional on a session being outstanding, which is a stronger promise than
//  an SDK can keep on an integrator's behalf across a background relaunch.
//

import CoreLocation
import Foundation
import os

//  The class carries no `@available` annotation and stores nothing typed to a
//  CoreLocation symbol from iOS 18. Both are deliberate, and the second is the
//  reason for the first.
//
//  `@available` is a compile-time guard; it does not stop the Objective-C runtime
//  from realizing a Swift class. Anything that walks the class list — XCTest,
//  crash reporters, analytics and DI frameworks all do — forces metadata
//  completion for every class in the process, and completing this one meant
//  resolving `CLServiceSession.AuthorizationRequirement?`. That is an enum, so its
//  layout cannot be known without its metadata, and below iOS 18 the accessor
//  returns null: `EXC_BAD_ACCESS` at launch, on every version from the 15.0 floor
//  to 17.x. It was found by running the suite on an iOS 17.0 simulator, where the
//  test runner segfaulted before a single test ran.
//
//  Storing the two values as `Any?` keeps the unavailable types out of the class
//  layout entirely. Method signatures may still name them — only stored properties
//  drive metadata completion — so the gating moves to the methods, where it costs
//  nothing.
internal final class ServiceSession: @unchecked Sendable {

    internal static let shared = ServiceSession()

    /// `CLServiceSession?` and `CLServiceSession.AuthorizationRequirement?` boxed
    /// as `Any?`. See the note above the class before giving these real types.
    private var sessionBox: Any?
    private var requirementBox: Any?
    private var diagnosticsTask: Task<Void, Never>?
    private let lock = NSLock()

    private init() {}

    /// Opens a session matching the authorization actually granted, replacing it
    /// when that grant changes. Idempotent, so it is safe to call on every
    /// authorization callback and every start.
    ///
    /// The requirement tracks what was *granted*, not what the SDK wants. Asking
    /// for `.always` while only When In Use is held puts the session into a
    /// permanently denied state instead of working at the level available.
    @available(iOS 18.0, *)
    internal func update(for status: CLAuthorizationStatus) {
        let wanted: CLServiceSession.AuthorizationRequirement?
        switch status {
        case .authorizedAlways:    wanted = .always
        case .authorizedWhenInUse: wanted = .whenInUse
        default:                   wanted = nil
        }

        let shouldOpen: Bool = lock.withLock {
            let current = requirementBox as? CLServiceSession.AuthorizationRequirement
            guard wanted != current else { return false }
            diagnosticsTask?.cancel()
            diagnosticsTask = nil
            (sessionBox as? CLServiceSession)?.invalidate()
            sessionBox = nil
            // Assigned through the binding rather than straight from the optional:
            // putting an `Optional` into an `Any?` boxes the `.none` itself, which
            // is a non-nil `Any` holding nothing.
            if let wanted {
                requirementBox = wanted
            } else {
                requirementBox = nil
            }
            return true
        }
        guard shouldOpen else { return }

        guard let wanted else {
            if WoosLog.isValidLevel(level: .trace) {
                Logger.sdklog.trace("\(LogEvent.v.rawValue) Permission: no CLServiceSession, location not authorized")
            }
            return
        }

        let opened = CLServiceSession(authorization: wanted)
        let task = Task { await Self.consume(opened.diagnostics) }
        lock.withLock {
            sessionBox = opened
            diagnosticsTask = task
        }
        if WoosLog.isValidLevel(level: .info) {
            Logger.sdklog.info("\(LogEvent.i.rawValue) Permission: CLServiceSession opened requiring \(wanted == .always ? "always" : "whenInUse", privacy: .public)")
        }
    }

    @available(iOS 18.0, *)
    private static func consume(_ diagnostics: CLServiceSession.Diagnostics) async {
        do {
            for try await diagnostic in diagnostics {
                if let problems = flags(in: diagnostic) {
                    Logger.sdklog.error("\(LogEvent.e.rawValue) Permission: CLServiceSession suspended: \(problems, privacy: .public)")
                } else if WoosLog.isValidLevel(level: .trace) {
                    Logger.sdklog.trace("\(LogEvent.v.rawValue) Permission: CLServiceSession running, nothing reported")
                }
            }
        } catch is CancellationError {
            // Replaced by a session at a different authorization level.
        } catch {
            Logger.sdklog.error("\(LogEvent.e.rawValue) Permission: CLServiceSession diagnostics failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Every reason CoreLocation gives for suspending the session, or nil when
    /// none are set — the healthy case.
    @available(iOS 18.0, *)
    private static func flags(in diagnostic: CLServiceSession.Diagnostic) -> String? {
        let set = [
            ("authDenied", diagnostic.authorizationDenied),
            ("authDeniedGlobally", diagnostic.authorizationDeniedGlobally),
            ("authRestricted", diagnostic.authorizationRestricted),
            ("insufficientlyInUse", diagnostic.insufficientlyInUse),
            ("fullAccuracyDenied", diagnostic.fullAccuracyDenied),
            ("alwaysAuthorizationDenied", diagnostic.alwaysAuthorizationDenied),
            ("serviceSessionRequired", diagnostic.serviceSessionRequired),
            ("authRequestInProgress", diagnostic.authorizationRequestInProgress),
        ].filter(\.1).map(\.0)
        return set.isEmpty ? nil : set.joined(separator: ",")
    }
}
