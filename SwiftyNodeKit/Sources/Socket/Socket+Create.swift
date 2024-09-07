//
//  Socket+Create.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 6/9/24.
//

import Foundation
import Darwin

public extension Socket {
    /// Creates a socket for communication.
    internal func createSocket() {
        socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket != nil, socket != -1 else {
            logError("Error creating socket")
            return
        }
        log("Socket created successfully")
    }

    /// Binds the created socket to a specific address.
    internal func bindSocket() {
        guard let socket = socket else { return }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &address.sun_path.0) { dest in
                _ = strcpy(dest, ptr)
            }
        }

        unlink(socketPath) // Remove any existing socket file

        if Darwin.bind(
            socket,
            withUnsafePointer(to: &address, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 } }),
            socklen_t(MemoryLayout<sockaddr_un>.size)
        ) == -1 {
            logError("Error binding socket - \(String(cString: strerror(errno)))")
            return
        }
        log("Binding to socket path: \(socketPath)")
    }

    /// Listens for connections on the bound socket.
    internal func listenOnSocket() {
        guard let socket = socket else { return }

        if Darwin.listen(socket, 1) == -1 {
            logError("Error listening on socket - \(String(cString: strerror(errno)))")
            return
        }
        log("Listening for connections...")
    }

    /// Waits for a connection and accepts it when available.
    internal func waitForConnection() {
        Task { @SocketActor in
            self.acceptConnection()
        }
    }

    /// Accepts a connection request from a client.
    internal func acceptConnection() {
        guard let socket = socket else { return }

        var clientAddress = sockaddr_un()
        var clientAddressLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        clientSocket = Darwin.accept(
            socket,
            withUnsafeMutablePointer(
                to: &clientAddress
            ) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
            },
            &clientAddressLen
        )

        if clientSocket == -1 {
            logError("Error accepting connection - \(String(cString: strerror(errno)))")
            return
        }
        log("Connection accepted!")
        delegate?.socketDidConnect(self)
    }
}
