//
//  NodeCommunicator.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation

class NodeCommunicator {
    var process: NodeProcess?
    var socket: Socket?

    init() {}

    /// Starts the socket, and returns the socket path
    func start() -> String {
        let name = "/tmp/module_\(UUID().uuidString).sock"
        self.socket = Socket(socketPath: name)
        socket!.startBroadcasting()
        return name
    }

    /// Sends data via the socket
    func send(_ data: Data) {
        socket?.sendData("Good morning!".data(using: .utf8)!)
    }

    /// Reads data from the socket
    func read() { // TODO: turn this into a delegate-based or callback-based thing
        socket?.readData()
    }

    /// Terminates the process and socket
    func terminate() {
        process?.process.terminate()
        socket?.stopBroadcasting()
    }

    /// Reads from the process's console. This function will cause the caller to hang if the
    /// process has not already been terminated.
    func readConsole() -> String {
        do {
            guard let data = try process?.pipe.fileHandleForReading.readToEnd() else { return "" }
            let output = String(data: data, encoding: .utf8)!
            return output
        } catch {
            return "Reading Error: \(error)"
        }
    }
}
