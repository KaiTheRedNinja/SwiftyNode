//
//  NodeCommunicator.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation
import Socket
import Log

/// Type alias for a native function callback closure
public typealias NativeFunction = (_ params: [String: Any]?) -> (any Codable)?

/// A class that manages communication with a NodeJS instance.
@NodeActor
public class NodeCommunicator {
    /// The NodeJS process
    internal var process: NodeProcess!
    /// The communication socket, used to communicate between Swift and NodeJS
    internal var socket: Socket!
    /// The assembler, used to combine multiple fragments into complete messages
    internal var assembler: ChunkAssembler!
    /// An array of `Data`, to be sent once the socket connects.
    internal var sendQueue: [Data] = []
    /// A map of callbacks to their IDs, which are called and deleted when the NodeJS process
    /// sends a response for the associated ID.
    internal var callResponses: [UUID: (JSONResponse) -> Void] = [:]
    /// A map of native functions to their names, which are called when the NodeJS process sends a method request
    internal var nativeFunctions: [String: NativeFunction] = [:]

    /// Creates an empty ``NodeCommunicator``
    public init() {}

    /// Starts the socket, and returns the socket path
    /// - Returns: The path to the Unix socket
    public func start() -> String {
        let name = "/tmp/module_\(UUID().uuidString).sock"
        self.socket = Socket(socketPath: name)
        socket.delegate = self
        socket.startBroadcasting()
        assembler = .init(chunkCallback: { [weak self] in
            self?.processChunk($0)
        })
        return name
    }

    /// Makes a JSON-RPC function notification via the socket
    /// - Parameters:
    ///   - method: The name of the method to call
    ///   - params: Parameters for the method, if any
    public func notify(method: String, params: [String: any Encodable]?) async throws {
        let request = JSONRequest(method: method, params: params, id: nil)
        let data = try JSONEncoder().encode(request)

        Task {
            try await self.send(data)
        }
    }

    /// Makes a JSON-RPC function request via the socket
    /// - Parameters:
    ///   - method: The name of the method to call
    ///   - params: Parameters for the method, if any
    ///   - returns: The type to return, or `Void.self` if the function is not expected to return anything.
    public func request<R>(method: String, params: [String: any Encodable]?, returns: R.Type) async throws -> R? {
        let id: UUID = UUID()
        let request = JSONRequest(method: method, params: params, id: id.uuidString)
        let data = try JSONEncoder().encode(request)

        Task {
            try await self.send(data)
        }

        let result: R? = try await withCheckedThrowingContinuation { cont in
            callResponses[id] = { response in
                defer {
                    self.callResponses.removeValue(forKey: id)
                }

                if let error = response.error {
                    Log.error("Returning error")
                    cont.resume(throwing: error)
                    return
                }

                let result = response.result as? R
                Log.log("Resuming")
                cont.resume(returning: result)
            }
        }

        return result
    }

    /// Registers a method that node can call
    /// - Parameters:
    ///   - methodName: The name of the method
    ///   - method: A callback closure, called when NodeJS requests the function.
    public func register(methodName: String, _ method: @escaping NativeFunction) {
        self.nativeFunctions[methodName] = method
    }

    /// Sends data via the socket.
    ///
    /// Data sent via the socket is prefixed with `[START: {id}]` and `[END: {id}]`, where `id` is a random integer
    /// between 0 and 10,000. This is so the receiving end can piece together large messages, which are sent in multiple
    /// parts.
    ///
    /// If the socket is not connected, requests are queued and sent sequentially after the socket connects. Any other
    /// errors will be thrown.
    /// - Parameter data: The data to send.
    private func send(_ data: Data) async throws {
        let id = Int.random(in: 0...10_000)
        let markedData = "[START: \(id)]".data(using: .utf8)! + data + "[END: \(id)]".data(using: .utf8)!
        sendQueue.append(markedData)
        guard socket.isConnected else {
            Log.error("Socket not connected")
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

    /// Processes a received chunk, sent from the NodeJS process.
    /// - Parameter chunk: The complete message chunk
    private func processChunk(_ chunk: String) {
        Log.info("Chunk: \(chunk)")
        let data = chunk.data(using: .utf8)!

        if let request = try? JSONRequest.decode(from: data) {
            let result = nativeFunctions[request.method]?(request.params) // TODO: allow throwing errors
            if let id = request.id {
                Log.info("Sending response \(result) to \(id)")
                let response = JSONResponse(result: result, id: id)
                do {
                    let responseData = try JSONEncoder().encode(response)
                    Task {
                        try await send(responseData)
                    }
                } catch {
                    Log.error("Error sending response: \(error)")
                }
            }
        } else if let result = try? JSONResponse.decode(from: data) {
            guard let uuid = UUID(uuidString: result.id) else {
                Log.error("Response has invalid UUID")
                return
            }
            callResponses[uuid]?(result)
        } else {
            Log.error("Chunk was neither a request or response")
        }
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
    public nonisolated func socketDidConnect(_ socket: Socket) {
        Task { @NodeActor in
            // clear the queue
            for item in sendQueue {
                try await socket.sendData(item)
            }
            sendQueue = []
        }
    }

    public nonisolated func socketDidRead(_ socket: Socket, data: Data) {
        Task { @NodeActor in
            assembler.processData(data)
        }
    }
}
