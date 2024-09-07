//
//  NodeCommunicator.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation
import Socket

public typealias NativeFunction = (_ params: [String: Any]?) -> (any Codable)?

@NodeActor
public class NodeCommunicator {
    internal var process: NodeProcess!
    internal var socket: Socket!
    internal var assembler: ChunkAssembler!
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
        assembler = .init(chunkCallback: { [weak self] in
            self?.processChunk($0)
        })
        return name
    }

    /// Makes a JSON-RPC function notification via the socket
    public func notify(method: String, params: [String: any Encodable]?) async throws {
        let request = JSONRequest(method: method, params: params, id: nil)
        let data = try JSONEncoder().encode(request)

        Task {
            try await self.send(data)
        }
    }

    /// Makes a JSON-RPC function request via the socket
    public func request<R>(method: String, params: [String: any Encodable]?, returns: R.Type) async throws -> R? {
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
        let id = Int.random(in: 0...10_000)
        let markedData = "[START: \(id)]".data(using: .utf8)! + data + "[END: \(id)]".data(using: .utf8)!
        sendQueue.append(markedData)
        guard socket.isConnected else {
            print("Socket not connected")
            return
        }

        for item in sendQueue {
            try await socket.sendData(item)
        }
        sendQueue = []
    }

    /// Processes a received chunk
    private func processChunk(_ chunk: String) {
        print("Chunk: \(chunk)")
        let data = chunk.data(using: .utf8)!
        do {
            let result = try JSONResponse.decode(from: data)
            guard let uuid = UUID(uuidString: result.id) else {
                print("Response has invalid UUID")
                return
            }
            callResponses[uuid]?(result)
        } catch {
            print("Error parsing response: \(error)")
        }
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
