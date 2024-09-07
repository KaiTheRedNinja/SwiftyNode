//
//  Socket.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation
import Darwin

/// A class that manages a Unix Domain Socket connection
public class Socket {
    /// The server socket's file reference
    internal var socket: Int32?
    /// The client socket's file reference
    internal var clientSocket: Int32?
    /// The path to the socket, as a string
    internal let socketPath: String

    /// The socket's delegate, informed of important events
    public weak var delegate: (any SocketDelegate)?

    /// Whether or not the socket is running and connected to a client socket
    public var isConnected: Bool {
        socket != nil && clientSocket != nil
    }

    /// Creates a ``Socket`` for a given socket path
    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    /// Starts the server and begins listening for connections.
    public func startBroadcasting() {
        createSocket()
        bindSocket()
        listenOnSocket()
        waitForConnection()
        beginReadData()
    }

    /// Sends the provided data to the connected client.
    ///
    /// This function breaks it up into chunks of 4096 bytes, as Unix sockets have a maximum write limit of 8192 bytes.
    /// - Parameter data: The data to send.
    public func sendData(_ data: Data) async throws {
        guard let clientSocket = clientSocket else {
            logError("No connected client.")
            throw SocketError.clientNotConnected
        }

        if data.isEmpty {
            logError("No data to send!")
            throw SocketError.noData
        }

        // Darwin.send has a send limit of around 8192 bytes, on my machine. I'm treating it as 4096 to be safe.
        let chunkSize = 4096
        var offset = 0

        while offset < data.count {
            let remainingBytes = data.count - offset
            let currentChunkSize = min(chunkSize, remainingBytes)

            let range = offset..<(offset + currentChunkSize)
            let chunk = data.subdata(in: range)

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                chunk.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                    let pointer = bytes.bindMemory(to: UInt8.self)
                    let bytesWritten = Darwin.send(clientSocket, pointer.baseAddress!, chunk.count, 0)

                    if bytesWritten == -1 {
                        logError("Error sending data: \(bytesWritten)")
                        cont.resume(throwing: SocketError.sendFailed)
                        return
                    }
                    log("\(bytesWritten) bytes written out of \(chunk.count) bytes")
                    cont.resume()
                }
            }

            offset += currentChunkSize
        }
    }

    /// Begins the process of reading data from the connected socket.
    ///
    /// The ``delegate`` is informed when reads are made.
    private func beginReadData() {
        Task { @SocketActor in
            while true {
                var buffer = [UInt8](repeating: 0, count: 1024)
                guard let socket = self.clientSocket else {
                    self.logError("Socket is nil")
                    return
                }

                let bytesRead = Darwin.read(socket, &buffer, buffer.count)
                if bytesRead <= 0 {
                    self.logError("Error reading from socket or connection closed: \(bytesRead)")
                    break // exit loop on error or closure of connection
                }

                // Print the data for debugging purposes
                let data = Data(buffer[..<bytesRead])
                self.log("Received data: \(data)")
                self.delegate?.socketDidRead(self, data: data)
            }
        }
    }

    /// Stops the server and closes any open connections.
    public func stopBroadcasting() {
        if let clientSocket = clientSocket {
            log("Closing client socket...")
            close(clientSocket)
        }
        if let socket = socket {
            log("Closing server socket...")
            close(socket)
        }
        unlink(socketPath)
        log("Broadcasting stopped.")
    }

    /// Logs a success message.
    /// - Parameter message: The message to log.
    internal func log(_ message: String) {
        print("ServerUnixSocket: \(message)")
    }

    /// Logs an error message.
    /// - Parameter message: The message to log.
    internal func logError(_ message: String) {
        print("ServerUnixSocket: [ERROR] \(message)")
    }
}

public protocol SocketDelegate: AnyObject {
    func socketDidConnect(_ socket: Socket)
    func socketDidRead(_ socket: Socket, data: Data)
}

public enum SocketError: Error {
    case clientNotConnected
    case noData
    case sendFailed
}
