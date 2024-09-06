//
//  NodeCommunicator.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation

class NodeCommunicator {
    var process: NodeProcess!
    var socket: Socket!
    var sendQueue: [Data] = []

    init() {}

    /// Starts the socket, and returns the socket path
    func start() -> String {
        let name = "/tmp/module_\(UUID().uuidString).sock"
        self.socket = Socket(socketPath: name)
        socket.delegate = self
        socket.startBroadcasting()
        return name
    }

    /// Sends data via the socket.
    ///
    /// If the socket is not connected, requests are queued and sent sequentially after the socket connects. Other errors are thrown.
    func send(_ data: Data) async throws {
        sendQueue.append(data)
        guard socket.isConnected else {
            print("Socket not connected")
            return
        }

        for item in sendQueue {
            try await socket.sendData(item)
        }
        sendQueue = []
    }

    /// Terminates the process and socket
    func terminate() {
        process.process.terminate()
        socket.stopBroadcasting()
    }

    /// Reads from the process's console. This function will cause the caller to hang if the
    /// process has not already been terminated.
    func readConsole() -> String {
        do {
            guard let data = try process.pipe.fileHandleForReading.readToEnd() else { return "" }
            let output = String(data: data, encoding: .utf8)!
            return output
        } catch {
            return "Reading Error: \(error)"
        }
    }
}

extension NodeCommunicator: SocketDelegate {
    func socketDidConnect(_ socket: Socket) {
        Task {
            // clear the queue
            for item in sendQueue {
                try await socket.sendData(item)
            }
            sendQueue = []
        }
    }
    
    func socketDidRead(_ socket: Socket, data: Data) {
        if let str = String(data: data, encoding: .utf8) {
            // Now you have converted the Data back to a string
            print("GOTTEN: \(str)")
        }
    }
}
