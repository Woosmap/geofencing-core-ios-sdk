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

@available(iOS 18.0, *)
internal final class ServiceSession: @unchecked Sendable {

    internal static let shared = ServiceSession()

    private var session: CLServiceSession?
    private var requirement: CLServiceSession.AuthorizationRequirement?
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
    internal func update(for status: CLAuthorizationStatus) {
        let wanted: CLServiceSession.AuthorizationRequirement?
        switch status {
        case .authorizedAlways:    wanted = .always
        case .authorizedWhenInUse: wanted = .whenInUse
        default:                   wanted = nil
        }

        let shouldOpen: Bool = lock.withLock {
            guard wanted != requirement else { return false }
            diagnosticsTask?.cancel()
            diagnosticsTask = nil
            session?.invalidate()
            session = nil
            requirement = wanted
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
            session = opened
            diagnosticsTask = task
        }
        if WoosLog.isValidLevel(level: .info) {
            Logger.sdklog.info("\(LogEvent.i.rawValue) Permission: CLServiceSession opened requiring \(wanted == .always ? "always" : "whenInUse", privacy: .public)")
        }
    }

    private static func consume(_ diagnostics: CLServiceSession.Diagnostics) async {
        do {
            for try await diagnostic in diagnostics {
                if let problems = flags(in: diagnostic) {
                    WoosFileLog.shared.append("CLServiceSession suspended: \(problems)")
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
