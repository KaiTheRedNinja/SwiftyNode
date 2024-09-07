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
    public static func log(_ message: StaticString, file: String = #fileID) {
        let parts = file.split(separator: "/")
        let subsystem = String(parts.first!)
        let category = String(parts.last!)
        let log = Logger(subsystem: subsystem, category: category)
        log.log("\(message)")
    }

    /// Logs the given piece of information
    public static func info(_ message: String, file: String = #fileID) {
        let parts = file.split(separator: "/")
        let subsystem = String(parts.first!)
        let category = String(parts.last!)
        let log = Logger(subsystem: subsystem, category: category)
        log.info("\(message)")
    }

    /// Logs the given error
    public static func error(_ message: String, file: String = #fileID) {
        let parts = file.split(separator: "/")
        let subsystem = String(parts.first!)
        let category = String(parts.last!)
        let log = Logger(subsystem: subsystem, category: category)
        log.error("\(message)")
    }
}
