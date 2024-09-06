//
//  Socket.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation
import Darwin

@preconcurrency
class Socket {
    private var socket: Int32?
    private var clientSocket: Int32?
    private let socketPath: String

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    /// Starts the server and begins listening for connections.
    func startBroadcasting() {
        createSocket()
        bindSocket()
        listenOnSocket()
        waitForConnection()
    }

    /// Creates a socket for communication.
    private func createSocket() {
        socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket != nil, socket != -1 else {
            logError("Error creating socket")
            return
        }
        log("Socket created successfully")
    }

    /// Binds the created socket to a specific address.
    private func bindSocket() {
        guard let socket = socket else { return }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &address.sun_path.0) { dest in
                _ = strcpy(dest, ptr)
            }
        }

        unlink(socketPath) // Remove any existing socket file

        if Darwin.bind(socket, withUnsafePointer(to: &address, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 } }), socklen_t(MemoryLayout<sockaddr_un>.size)) == -1 {
            logError("Error binding socket - \(String(cString: strerror(errno)))")
            return
        }
        log("Binding to socket path: \(socketPath)")
    }

    /// Listens for connections on the bound socket.
    private func listenOnSocket() {
        guard let socket = socket else { return }

        if Darwin.listen(socket, 1) == -1 {
            logError("Error listening on socket - \(String(cString: strerror(errno)))")
            return
        }
        log("Listening for connections...")
    }

    /// Waits for a connection and accepts it when available.
    private func waitForConnection() {
        DispatchQueue.global().async { [weak self] in
            self?.acceptConnection()
        }
    }

    /// Accepts a connection request from a client.
    private func acceptConnection() {
        guard let socket = socket else { return }

        var clientAddress = sockaddr_un()
        var clientAddressLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        clientSocket = Darwin.accept(socket, withUnsafeMutablePointer(to: &clientAddress, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 } }), &clientAddressLen)

        if clientSocket == -1 {
            logError("Error accepting connection - \(String(cString: strerror(errno)))")
            return
        }
        log("Connection accepted!")
    }

    /// Sends the provided data to the connected client.
    /// - Parameter data: The data to send.
    func sendData(_ data: Data) {
        guard let clientSocket = clientSocket else {
            logError("No connected client.")
            return
        }

        if data.isEmpty {
            logError("No data to send!")
            return
        }

        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let pointer = bytes.bindMemory(to: UInt8.self)
            let bytesWritten = Darwin.send(clientSocket, pointer.baseAddress!, data.count, 0)

            if bytesWritten == -1 {
                logError("Error sending data")
                return
            }
            log("\(bytesWritten) bytes written")
        }
    }

    /// Reads data from the connected socket.
    func readData() {
        DispatchQueue.global().async {
            while true {
                var buffer = [UInt8](repeating: 0, count: 1024)
                guard let socket = self.clientSocket else {
                    self.logError("Socket is nil")
                    return
                }

                let bytesRead = Darwin.read(socket, &buffer, buffer.count)
                if bytesRead <= 0 {
                    self.logError("Error reading from socket or connection closed")
                    break // exit loop on error or closure of connection
                }

                // Print the data for debugging purposes
                let data = Data(buffer[..<bytesRead])
                self.log("Received data: \(data)")

                if let str = String(data: data, encoding: .utf8) {
                    // Now you have converted the Data back to a string
                    print(str)
                }
            }
        }
    }

    /// Stops the server and closes any open connections.
    func stopBroadcasting() {
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
    private func log(_ message: String) {
        print("ServerUnixSocket: \(message)")
    }

    /// Logs an error message.
    /// - Parameter message: The message to log.
    private func logError(_ message: String) {
        print("ServerUnixSocket: [ERROR] \(message)")
    }
}
