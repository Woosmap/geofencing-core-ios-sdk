//
//  RegionChangeCounter.swift
//  WoosmapGeofencing
//
//  Temporary instrumentation for #167.
//
//  `handleRegionChange()` tears down every monitored region and restarts location
//  updates. Gating it on `!transition.initialState` should collapse a burst of N POI
//  registrations into zero cycles while leaving crossings untouched — but nothing in
//  the databases records how often it ran, so the gate cannot be measured from a
//  field capture.
//
//  This counts the cycles and rides along in `ZLOCATIONDB.ZLOCATIONDESCRIPTION`,
//  which is already exported in `AppDump.zip`. No new file, no new permission, no
//  extra export step for a tester.
//
//  Remove once the measurement is in.
//

import Foundation

internal final class RegionChangeCounter: @unchecked Sendable {

    internal static let shared = RegionChangeCounter()

    /// Identifies this process, so two launches are not read as one run. Counters
    /// reset on relaunch; without this a dump shows `restarts` going backwards.
    internal let launchId: Int32

    private var value: Int = 0
    private let lock = NSLock()

    private init() {
        launchId = ProcessInfo.processInfo.processIdentifier
    }

    internal var count: Int { lock.withLock { value } }

    internal func increment() {
        lock.withLock { value += 1 }
    }
}
