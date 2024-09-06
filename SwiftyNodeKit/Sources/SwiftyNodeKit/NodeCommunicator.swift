//
//  NodeCommunicator.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation
import Socket

public typealias NativeFunction = (_ params: [String: Any]?) -> (any Codable)?

public class NodeCommunicator {
    internal var process: NodeProcess!
    internal var socket: Socket!
    internal var sendQueue: [Data] = []
    internal var callResponses: [UUID: (JSONResponse) -> Void] = [:]
    internal var nativeFunctions: [String: NativeFunction] = [:]

    public init() {}

    /// Starts the socket, and returns the socket path
    public func start() -> String {
        let name = "/tmp/module_\(UUID().uuidString).sock"
        self.socket = Socket(socketPath: name)
        socket.delegate = self
        socket.startBroadcasting()
        return name
    }

    /// Makes a JSON-RPC function request via the socket
    public func request<R>(method: String, params: [String: any Codable], returns: R.Type) async throws -> R? {
        let id: UUID = UUID()
        let request = JSONRequest(method: method, params: params, id: id.uuidString)
        let data = try JSONEncoder().encode(request)

        Task {
            try await self.send(data)
        }

        let result: R? = try await withCheckedThrowingContinuation { cont in
            callResponses[id] = { response in
                print("Response yes")

                defer {
                    self.callResponses.removeValue(forKey: id)
                }

                if let error = response.error {
                    print("Returning error")
                    cont.resume(throwing: error)
                    return
                }

                let result = response.result as? R
                print("Resuming")
                cont.resume(returning: result)
            }
        }

        return result
    }

    /// Registers a method that node can call
    func register(methodName: String, _ method: @escaping NativeFunction) {
        self.nativeFunctions[methodName] = method
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
    public func terminate() {
        process?.process.terminate()
        socket?.stopBroadcasting()
    }

    /// Reads from the process's console. This function will cause the caller to hang if the
    /// process has not already been terminated.
    public func readConsole() -> String {
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
    public func socketDidConnect(_ socket: Socket) {
        Task {
            // clear the queue
            for item in sendQueue {
                try await socket.sendData(item)
            }
            sendQueue = []
        }
    }
    
    public func socketDidRead(_ socket: Socket, data: Data) {
        do {
            let response = try JSONResponse.decode(from: data)
            guard let uuid = UUID(uuidString: response.id) else {
                print("Response does not have a valid UUID")
                return
            }

            print("Response: \(response)")

            callResponses[uuid]?(response)
        } catch {
            print("Error parsing JSON: \(error.localizedDescription)")
        }
    }
}
