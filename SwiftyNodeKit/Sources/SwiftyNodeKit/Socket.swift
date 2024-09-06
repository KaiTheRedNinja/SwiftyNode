//
//  Socket.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Darwin

func makeSocket(path: String) -> Int32? {
    let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    guard socket != -1 else {
        print("Error creating socket")
        return nil
    }

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    path.withCString { ptr in
        withUnsafeMutablePointer(to: &address.sun_path.0) { dest in
            _ = strcpy(dest, ptr)
        }
    }

    unlink(path) // Remove any existing socket file

    if Darwin.bind(
        socket,
        withUnsafePointer(to: &address, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 } }),
        socklen_t(MemoryLayout<sockaddr_un>.size)
    ) == -1 {
        print("Error binding socket - \(String(cString: strerror(errno)))")
        return nil
    }

    return socket
}

func beginListening(socket: Int32, count: Int32 = 1) {
    print("Listening")
    Darwin.listen(socket, count)
}

func acceptConnection(socket: Int32) {
    print("Accepting connection")
    let connection = Darwin.accept(socket, nil, nil)
    print("Accepted connection")
    print(connection)
}
