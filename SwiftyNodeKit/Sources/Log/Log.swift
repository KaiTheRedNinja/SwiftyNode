//
//  Log.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 7/9/24.
//

import Foundation
import OSLog

/// A helper object for logging
public enum Log {
    /// Logs the given log. This log must be a static string.
    @inlinable
    public static func log(_ message: StaticString, fileID: String = #fileID, line: Int = #line) {
        let parts = fileID.split(separator: "/")
        let subsystem = String(parts.first!)
        let category = String(parts.last!)
        let log = Logger(subsystem: subsystem, category: category)
        log.log("[\(category):\(line)] \(message)")
    }

    /// Logs the given piece of information
    @inlinable
    public static func info(_ message: String, fileID: String = #fileID, line: Int = #line) {
        let parts = fileID.split(separator: "/")
        let subsystem = String(parts.first!)
        let category = String(parts.last!)
        let log = Logger(subsystem: subsystem, category: category)
        log.info("[\(category):\(line)] \(message)")
    }

    /// Logs the given error
    @inlinable
    public static func error(_ message: String, fileID: String = #fileID, line: Int = #line) {
        let parts = fileID.split(separator: "/")
        let subsystem = String(parts.first!)
        let category = String(parts.last!)
        let log = Logger(subsystem: subsystem, category: category)
        log.error("[\(category):\(line)] \(message)")
    }
}
