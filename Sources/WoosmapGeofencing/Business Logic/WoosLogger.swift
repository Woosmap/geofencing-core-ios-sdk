//
//  WoosLogger.swift
//  WoosmapGeofencingCore
//
//  Created by WGS on 15/09/23.
//  Copyright © 2023 Web Geo Services. All rights reserved.
//

import Foundation
import os

@available(iOS 14.0, *)
extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs the view cycles like a view that appeared.
    ///
    /// Debug builds get a stand-in that writes the same lines to `os.Logger` *and*
    /// to a per-launch file, so evidence survives the app being killed. Release
    /// builds keep the plain `os.Logger`, privacy redaction included — see
    /// `WoosFileLog` at the foot of this file.
    #if DEBUG
    @available(iOS 14.0, *)
    static let sdklog = MirroringLogger(subsystem: subsystem, category: "WoosmapGeofencingSDK")
    #else
    @available(iOS 14.0, *)
    static let sdklog = Logger(subsystem: subsystem, category: "WoosmapGeofencingSDK")
    #endif
}

/// Enum which maps an appropiate symbol which added as prefix for each log message
///
/// - error: Log type error
/// - info: Log type info
/// - debug: Log type debug
/// - verbose: Log type verbose
/// - warning: Log type warning
/// - severe: Log type severe
internal enum LogEvent: String {
    case s = "[🔥]" // severe
    case e = "[‼️]" // error
    case w = "[⚠️]" // warning
    case i = "[ℹ️]" // info
    case d = "[💬]" // debug
    case v = "[🔬]" // verbose
}


/// Wrapping Swift.print() within DEBUG flag
///
/// - Note: *print()* might cause [security vulnerabilities](https://codifiedsecurity.com/mobile-app-security-testing-checklist-ios/)
///
/// - Parameter object: The object which is to be logged
///
func print(_ object: Any) {
    // Only allowing in DEBUG mode
    #if DEBUG
    Swift.print(object)
    #endif
}


class WoosLog {
    
    static var dateFormat = "yyyy-MM-dd hh:mm:ssSSS"
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
    }
    
    private static var isLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Loging methods
    /// Logs error messages on console with prefix [‼️]
    ///
    /// - Parameters:
    ///   - object: Object or message to be logged
    ///   - filename: File name from where loggin to be done
    ///   - line: Line number in file from where the logging is done
    ///   - column: Column number of the log message
    ///   - funcName: Name of the function from where the logging is done
    class func error( _ object: Any, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        if isLoggingEnabled {
            print("WoosmapGeofencingSDK: \(Date().toString()) \(LogEvent.e.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(column) \(funcName) -> \(object)")
        }
    }
    
    /// Logs info messages on console with prefix [ℹ️]
    ///
    /// - Parameters:
    ///   - object: Object or message to be logged
    ///   - filename: File name from where loggin to be done
    ///   - line: Line number in file from where the logging is done
    ///   - column: Column number of the log message
    ///   - funcName: Name of the function from where the logging is done
    class func info ( _ object: Any, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        if isLoggingEnabled {
            print("WoosmapGeofencingSDK: \(Date().toString()) \(LogEvent.i.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(column) \(funcName) -> \(object)")
        }
    }
    
    /// Logs debug messages on console with prefix [💬]
    ///
    /// - Parameters:
    ///   - object: Object or message to be logged
    ///   - filename: File name from where loggin to be done
    ///   - line: Line number in file from where the logging is done
    ///   - column: Column number of the log message
    ///   - funcName: Name of the function from where the logging is done
    class func debug( _ object: Any, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        if isLoggingEnabled {
            print("WoosmapGeofencingSDK: \(Date().toString()) \(LogEvent.d.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(column) \(funcName) -> \(object)")
        }
    }
    
    /// Logs messages verbosely on console with prefix [🔬]
    ///
    /// - Parameters:
    ///   - object: Object or message to be logged
    ///   - filename: File name from where loggin to be done
    ///   - line: Line number in file from where the logging is done
    ///   - column: Column number of the log message
    ///   - funcName: Name of the function from where the logging is done
    class func trace( _ object: Any, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        if isLoggingEnabled {
            print("WoosmapGeofencingSDK: \(Date().toString()) \(LogEvent.v.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(column) \(funcName) -> \(object)")
        }
    }
    
    /// Logs warnings verbosely on console with prefix [⚠️]
    ///
    /// - Parameters:
    ///   - object: Object or message to be logged
    ///   - filename: File name from where loggin to be done
    ///   - line: Line number in file from where the logging is done
    ///   - column: Column number of the log message
    ///   - funcName: Name of the function from where the logging is done
    class func warning( _ object: Any, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        if isLoggingEnabled {
            print("WoosmapGeofencingSDK: \(Date().toString()) \(LogEvent.w.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(column) \(funcName) -> \(object)")
        }
    }
    
    /// Logs severe events on console with prefix [🔥]
    ///
    /// - Parameters:
    ///   - object: Object or message to be logged
    ///   - filename: File name from where loggin to be done
    ///   - line: Line number in file from where the logging is done
    ///   - column: Column number of the log message
    ///   - funcName: Name of the function from where the logging is done
    class func critical( _ object: Any, filename: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        if isLoggingEnabled {
            print("WoosmapGeofencingSDK: \(Date().toString()) \(LogEvent.s.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(column) \(funcName) -> \(object)")
        }
    }
    
    
    /// Extract the file name from the file path
    ///
    /// - Parameter filePath: Full file path in bundle
    /// - Returns: File Name with extension
    private class func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.isEmpty ? "" : components.last!
    }
    
    class func isValidLevel(level:WosmapLogEvent) -> Bool{
        if (level.rawValue <= logLevelSDK.rawValue ){
            return true
        }
        else{
            return false
        }
    }
}

internal extension Date {
    func toString() -> String {
        return WoosLog.dateFormatter.string(from: self as Date)
    }
}



// MARK: - Debug-only session log

// Everything below is compiled out of release builds. `Logger.sdklog` keeps its
// `os.Logger` type and behaviour there, including privacy redaction, so the
// shipped framework is unchanged by any of this.
//
// Why a file at all, when the SDK already logs through `os.Logger`: the useful
// evidence is what happened *before* the app was killed, and `OSLogStore` on iOS
// can only be opened for the current process. A relaunched process cannot read
// what its predecessor logged, which is exactly the window a background wake-up
// investigation needs. Appending to a file as we go survives the kill.
#if DEBUG

/// Accepted so the handful of `privacy:` call sites still compile against the
/// mirroring shim. A debug build logs to a developer's own device, so the marker
/// is recorded in the type signature and not acted on.
internal struct SDKLogPrivacy {
    static let `public` = SDKLogPrivacy()
    static let `private` = SDKLogPrivacy()
    static let auto = SDKLogPrivacy()
    static let sensitive = SDKLogPrivacy()
}

/// Stands in for `OSLogMessage` so existing call sites need no edit.
///
/// `os.Logger` takes a compile-time specialised `OSLogMessage`; the file sink
/// needs a plain `String`. This builds one through the same interpolation syntax,
/// so `Logger.sdklog.debug("\(a) \(b, privacy: .public)")` compiles either way.
internal struct SDKLogMessage: ExpressibleByStringInterpolation {
    let text: String

    init(stringLiteral value: String) { text = value }
    init(stringInterpolation: Interpolation) { text = stringInterpolation.rendered }

    internal struct Interpolation: StringInterpolationProtocol {
        var rendered = ""

        init(literalCapacity: Int, interpolationCount: Int) {
            rendered.reserveCapacity(literalCapacity + interpolationCount * 8)
        }

        mutating func appendLiteral(_ literal: String) { rendered += literal }

        mutating func appendInterpolation<T>(_ value: T) {
            rendered += String(describing: value)
        }

        mutating func appendInterpolation<T>(_ value: T, privacy: SDKLogPrivacy) {
            rendered += String(describing: value)
        }
    }
}

/// Writes every SDK log line to `os.Logger` as before, and to the session file.
///
/// Forwarding marks the text `.public` because it has already been composed here;
/// that only applies to debug builds, where the alternative would be a Console
/// full of `<private>`.
@available(iOS 14.0, *)
internal struct MirroringLogger {
    private let osLogger: Logger

    init(subsystem: String, category: String) {
        osLogger = Logger(subsystem: subsystem, category: category)
    }

    private func emit(_ level: String, _ message: SDKLogMessage, _ toConsole: (String) -> Void) {
        toConsole(message.text)
        WoosFileLog.append(level: level, message: message.text)
    }

    func debug(_ message: SDKLogMessage) { emit("DEBUG", message) { osLogger.debug("\($0, privacy: .public)") } }
    func trace(_ message: SDKLogMessage) { emit("TRACE", message) { osLogger.trace("\($0, privacy: .public)") } }
    func info(_ message: SDKLogMessage) { emit("INFO", message) { osLogger.info("\($0, privacy: .public)") } }
    func notice(_ message: SDKLogMessage) { emit("NOTICE", message) { osLogger.notice("\($0, privacy: .public)") } }
    func warning(_ message: SDKLogMessage) { emit("WARN", message) { osLogger.warning("\($0, privacy: .public)") } }
    func error(_ message: SDKLogMessage) { emit("ERROR", message) { osLogger.error("\($0, privacy: .public)") } }
    func critical(_ message: SDKLogMessage) { emit("CRIT", message) { osLogger.critical("\($0, privacy: .public)") } }
    func fault(_ message: SDKLogMessage) { emit("FAULT", message) { osLogger.fault("\($0, privacy: .public)") } }
    func log(_ message: SDKLogMessage) { emit("LOG", message) { osLogger.log("\($0, privacy: .public)") } }
}

/// One file per process launch, under `Application Support/WoosmapLogs`.
///
/// That directory is the one a device dump already collects alongside
/// `Woosmap.sqlite`, so a capture picks the logs up without extra steps.
///
/// The session id is the point of the whole thing. A new file, or a new id on the
/// `=== session` banner, means the process was killed and relaunched — which is
/// otherwise invisible in the database and is the difference between "iOS killed
/// us" and "the SDK dropped the state itself".
internal enum WoosFileLog {

    /// Distinguishes this launch from the one before it.
    internal static let sessionID = String(UUID().uuidString.prefix(8))

    /// Session files kept before the oldest are pruned.
    private static let sessionsKept = 20

    /// A stationary device can log for hours; stop before a debug build fills the
    /// container. Hit in practice only by a runaway loop.
    private static let maximumBytesPerSession = 8 * 1024 * 1024

    private static let lock = NSLock()
    private static var handle: FileHandle?
    private static var bytesWritten = 0
    private static var started = false
    private static var stopped = false

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Where the dump should look. `nil` only if the container is unreachable.
    internal private(set) static var fileURL: URL?

    internal static var directoryURL: URL? {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true) else { return nil }
        return support.appendingPathComponent("WoosmapLogs", isDirectory: true)
    }

    /// Appends one line, synchronously.
    ///
    /// Synchronous on purpose: a background wake can be killed at any moment, and
    /// anything still sitting in a queue at that point is the part worth reading.
    /// `write(2)` through an append-mode descriptor reaches the page cache before
    /// this returns, so it survives the kill without an `fsync` on every line.
    internal static func append(level: String, message: String) {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return }
        if !started { start() }
        guard let handle else { return }

        let line = "\(timestampFormatter.string(from: Date())) [\(sessionID)] \(level) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        // Failures here are not reportable — logging the failure would recurse.
        try? handle.write(contentsOf: data)
        bytesWritten += data.count

        if bytesWritten >= maximumBytesPerSession {
            let notice = "\(timestampFormatter.string(from: Date())) [\(sessionID)] WARN session log capped at \(maximumBytesPerSession) bytes, stopping\n"
            if let data = notice.data(using: .utf8) { try? handle.write(contentsOf: data) }
            try? handle.close()
            WoosFileLog.handle = nil
            stopped = true
        }
    }

    /// Caller holds `lock`.
    private static func start() {
        started = true
        guard let directory = directoryURL else { return }
        let manager = FileManager.default
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        // Application Support is backed up by default, and these are throwaway.
        var excluded = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? excluded.setResourceValues(values)
        prune(in: directory, using: manager)

        // Names sort chronologically, which is what `prune` relies on.
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.timeZone = TimeZone.current
        let url = directory.appendingPathComponent("session-\(stamp.string(from: Date()))-\(sessionID).log")
        guard manager.createFile(atPath: url.path, contents: nil),
              let opened = try? FileHandle(forWritingTo: url) else { return }
        _ = try? opened.seekToEnd()
        handle = opened
        fileURL = url
        writeBanner()
    }

    /// Caller holds `lock`, and `handle` is open.
    private static func writeBanner() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let banner = """
        === session \(sessionID) started \(timestampFormatter.string(from: Date()))
        === app \(Bundle.main.bundleIdentifier ?? "?") \(version) (\(build))
        === os \(ProcessInfo.processInfo.operatingSystemVersionString)

        """
        if let data = banner.data(using: .utf8) {
            try? handle?.write(contentsOf: data)
            bytesWritten += data.count
        }
    }

    /// Keeps the newest `sessionsKept - 1` files so this launch's makes the limit.
    ///
    /// Caller holds `lock`.
    private static func prune(in directory: URL, using manager: FileManager) {
        guard let existing = try? manager.contentsOfDirectory(at: directory,
                                                              includingPropertiesForKeys: nil) else { return }
        let sessions = existing.filter { $0.lastPathComponent.hasPrefix("session-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard sessions.count >= sessionsKept else { return }
        for url in sessions.prefix(sessions.count - sessionsKept + 1) {
            try? manager.removeItem(at: url)
        }
    }
}

#endif
