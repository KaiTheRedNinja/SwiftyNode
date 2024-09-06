//
//  NodeCommunicator.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation
import Socket

class NodeCommunicator {
    var process: NodeProcess!
    var socket: Socket!
    var sendQueue: [Data] = []

    var callResponses: [UUID: (JSONResponse) -> Void] = [:]

    init() {}

    /// Starts the socket, and returns the socket path
    func start() -> String {
        let name = "/tmp/module_\(UUID().uuidString).sock"
        self.socket = Socket(socketPath: name)
        socket.delegate = self
        socket.startBroadcasting()
        return name
    }

    /// Makes a JSON-RPC function request via the socket
    func request<R>(method: String, params: [String: any Codable], returns: R.Type) async throws -> R? {
        let id: UUID = UUID()
        let request = JSONRequest(method: method, params: params, id: id.uuidString)
        let data = try JSONEncoder().encode(request)
        Task {
            try await self.send(data)
        }
        return await withCheckedContinuation { cont in
            callResponses[id] = { response in
                let result = response.result as? R
                cont.resume(returning: result)
            }
        }
    }

    /// Sends data via the socket.
    ///
    /// If the socket is not connected, requests are queued and sent sequentially after the socket connects. Other errors are thrown.
    private func send(_ data: Data) async throws {
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

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let object = object as? [String: Any] else {
                print("Could not parse top level JSON")
                return
            }
            if let id = object["id"] as? String {
                print("Response: \(id)")
            }
        } catch {
            print("Error parsing JSON: \(error.localizedDescription)")
        }
    }
}
