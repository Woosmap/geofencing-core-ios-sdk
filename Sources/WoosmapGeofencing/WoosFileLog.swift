//
//  WoosFileLog.swift
//  WoosmapGeofencing
//
//  An append-only log on disk, alongside the unified log.
//
//  `OSLogStore` on iOS admits no scope but `.currentProcessIdentifier`, and every
//  background relaunch is a new process. An app exporting its own diagnostics can
//  therefore only ever report the launch it is in — which, for geofencing, is the
//  launch *after* the interesting one. This file survives relaunches, so a support
//  bundle can show what happened while the app was last awake in the background.
//
//  Off by default. Logging to disk continuously is the integrator's decision, not
//  the SDK's: `WoosmapGeofenceManager.shared.setFileLoggingEnabled(true)`.
//

import Foundation
import os

public final class WoosFileLog: @unchecked Sendable {

    public static let shared = WoosFileLog()

    /// Written inside `Application Support` so an app that already zips that
    /// directory for support picks it up with no extra work.
    private static let fileName = "WoosmapSDK.log"
    /// Rotated at this size, keeping one previous generation. Two files bound the
    /// footprint; a device left running for weeks must not fill the container.
    private static let maxBytes = 1_500_000

    private let queue = DispatchQueue(label: "com.woosmap.filelog", qos: .utility)
    private var enabled = false
    private let lock = NSLock()

    private lazy var stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.timeZone = .current
        return f
    }()

    private init() {}

    public var isEnabled: Bool { lock.withLock { enabled } }

    public func setEnabled(_ on: Bool) {
        lock.withLock { enabled = on }
        guard on else { return }
        // A launch marker is the point of the file: it is how a reader tells one
        // background wake-up from the next, which no single-process log can show.
        append("=== launch \(ProcessInfo.processInfo.processIdentifier) ===")
    }

    /// Directory the log lives in, or nil when it cannot be resolved.
    public static var directory: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true)
    }

    public static var fileURL: URL? { directory?.appendingPathComponent(fileName) }

    /// Appends one line. Cheap and non-blocking for the caller; serialised on its
    /// own queue so logging from a CoreLocation callback cannot stall delivery.
    public func append(_ line: String) {
        guard isEnabled, let url = Self.fileURL else { return }
        let text = "\(stamp.string(from: Date()))  \(line)\n"
        queue.async {
            guard let data = text.data(using: .utf8) else { return }
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            if let end = try? handle.seekToEnd() {
                if end > UInt64(Self.maxBytes) {
                    try? handle.close()
                    self.rotate(url)
                    guard let fresh = try? FileHandle(forWritingTo: url) else { return }
                    try? fresh.write(contentsOf: data)
                    try? fresh.close()
                    return
                }
            }
            try? handle.write(contentsOf: data)
        }
    }

    /// Keeps one previous generation so a rotation mid-incident does not lose it.
    private func rotate(_ url: URL) {
        let fm = FileManager.default
        let previous = url.appendingPathExtension("1")
        try? fm.removeItem(at: previous)
        try? fm.moveItem(at: url, to: previous)
        fm.createFile(atPath: url.path, contents: nil)
    }

    /// Removes both generations.
    public func clear() {
        guard let url = Self.fileURL else { return }
        queue.async {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("1"))
        }
    }
}
