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

func beginListening(socket: Int32, count: Int32 = 2) {
    print("Listening")
    Darwin.listen(socket, count)
}

func acceptConnection(socket: Int32) {
    print("Accepting connection")
    let connection = Darwin.accept(socket, nil, nil)
    print("Accepted connection")
    print(connection)
}

import Foundation
private let system_socket = Darwin.socket
private let system_connect = Darwin.connect
private let system_close = Darwin.close
private let system_recv = Darwin.recv
private let system_send = Darwin.send
private let system_sendto = Darwin.sendto
typealias fdmask = Int32

public enum UniSocketError: Error {
    case error(detail: String)
}

public enum UniSocketStatus: String {
    case none
    case stateless
    case connected
    case listening
    case readable
    case writable
}

public typealias UniSocketTimeout = (connect: UInt, read: UInt, write: UInt)

public class UniSocket {

    public var timeout: UniSocketTimeout
    private(set) var status: UniSocketStatus = .none
    private var fd: Int32 = -1
    private var fdset = fd_set()
    private let fdmask_size: Int
    private let fdmask_bits: Int
    private let peer: String
    private var peer_addrinfo: UnsafeMutablePointer<addrinfo>
    private var peer_local = sockaddr_un()
    private var buffer: UnsafeMutablePointer<UInt8>
    private let bufferSize = 32768

    public init(peer: String, port: Int32? = nil, timeout: UniSocketTimeout = (connect: 5, read: 5, write: 5)) throws {
        guard peer.count > 0 else {
            throw UniSocketError.error(detail: "invalid peer name")
        }
        self.timeout = timeout
        self.peer = peer
        fdmask_size = MemoryLayout<fdmask>.size
        fdmask_bits = fdmask_size * 8
        buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        peer_addrinfo = UnsafeMutablePointer<addrinfo>.allocate(capacity: 1)
        memset(peer_addrinfo, 0, MemoryLayout<addrinfo>.size)
        peer_local.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &peer_local.sun_path.0) { ptr in
            _ = peer.withCString {
                strcpy(ptr, $0)
            }
        }
        peer_addrinfo.pointee.ai_family = PF_LOCAL
        peer_addrinfo.pointee.ai_socktype = SOCK_STREAM
        peer_addrinfo.pointee.ai_protocol = 0
        let ptr: UnsafeMutablePointer<sockaddr_un> = withUnsafeMutablePointer(to: &peer_local) { $0 }
        peer_addrinfo.pointee.ai_addr = ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        peer_addrinfo.pointee.ai_addrlen = socklen_t(MemoryLayout<sockaddr_un>.size)
    }

    deinit {
        try? close()
        buffer.deallocate()
        peer_addrinfo.deallocate()
    }

    private func FD_SET() -> Void {
        let index = Int(fd) / fdmask_bits
        let bit = Int(fd) % fdmask_bits
        var mask: fdmask = 1 << bit
        withUnsafePointer(to: &mask) { src in
            withUnsafeMutablePointer(to: &fdset) { dst in
                memset(dst, 0, MemoryLayout<fd_set>.size)
                memcpy(dst + (index * fdmask_size), src, fdmask_size)
            }
        }
    }

    public func attach() throws -> Void {
        guard status == .none else {
            throw UniSocketError.error(detail: "socket is \(status)")
        }
        var rc: Int32
        var errstr: String? = ""
        var ai: UnsafeMutablePointer<addrinfo>? = peer_addrinfo
        while ai != nil {
            fd = system_socket(ai!.pointee.ai_family, ai!.pointee.ai_socktype, ai!.pointee.ai_protocol)
            if fd == -1 {
                ai = ai?.pointee.ai_next
                continue
            }
            FD_SET()
            let flags = fcntl(fd, F_GETFL)
            if flags != -1, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 {
                rc = system_connect(fd, ai!.pointee.ai_addr, ai!.pointee.ai_addrlen)
                if rc == 0 {
                    break
                }
                if errno != EINPROGRESS {
                    errstr = String(validatingCString: strerror(errno)) ?? "unknown error code"
                } else if let e = waitFor(.connected) {
                    errstr = e
                } else {
                    break
                }
            } else {
                errstr = String(validatingCString: strerror(errno)) ?? "unknown error code"
            }
            _ = system_close(fd)
            fd = -1
            ai = ai?.pointee.ai_next
        }
        if fd == -1 {
            throw UniSocketError.error(detail: "failed to attach socket to '\(peer)' (\(errstr ?? ""))")
        }
        status = .connected
    }

    public func close() throws -> Void {
        if status == .connected {
            shutdown(fd, Int32(SHUT_RDWR))
            usleep(10000)
        }
        if fd != -1 {
            _ = system_close(fd)
            fd = -1
        }
        status = .none
    }

    private func waitFor(_ status: UniSocketStatus, timeout: UInt? = nil) -> String? {
        var rc: Int32
        var fds = fdset
        var timer = timeval()
        if let t = timeout {
            timer.tv_sec = time_t(t)
        }
        switch status {
        case .connected:
            if timeout == nil {
                timer.tv_sec = time_t(self.timeout.connect)
            }
            rc = select(fd + 1, nil, &fds, nil, &timer)
        case .readable:
            if timeout == nil {
                timer.tv_sec = time_t(self.timeout.read)
            }
            rc = select(fd + 1, &fds, nil, nil, &timer)
        case .writable:
            if timeout == nil {
                timer.tv_sec = time_t(self.timeout.write)
            }
            rc = select(fd + 1, nil, &fds, nil, &timer)
        default:
            return nil
        }
        if rc > 0 {
            return nil
        } else if rc == 0 {
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &rc, &len)
            if rc == 0 {
                rc = ETIMEDOUT
            }
        } else {
            rc = errno
        }
        return String(validatingCString: strerror(rc)) ?? "unknown error code"
    }

    public func recv(min: Int = 1, max: Int? = nil) throws -> Data {
        guard status == .connected || status == .stateless else {
            throw UniSocketError.error(detail: "socket is \(status)")
        }
        if let errstr = waitFor(.readable) {
            throw UniSocketError.error(detail: errstr)
        }
        var rc: Int = 0
        var data = Data(bytes: buffer, count: 0)
        while rc == 0 {
            var limit = bufferSize
            if let m = max, (m - data.count) < bufferSize {
                limit = m - data.count
            }
            rc = system_recv(fd, buffer, limit, 0)
            if rc == 0 {
                try? close()
                throw UniSocketError.error(detail: "connection closed by remote host")
            } else if rc == -1 {
                let errstr = String(validatingCString: strerror(errno)) ?? "unknown error code"
                throw UniSocketError.error(detail: "failed to read from socket, \(errstr)")
            }
            data.append(buffer, count: rc)
            if let m = max, data.count >= m {
                break
            } else if max == nil, rc == bufferSize, waitFor(.readable, timeout: 0) == nil {
                rc = 0
            } else if data.count >= min {
                break
            }
        }
        return data
    }

    public func send(_ buffer: Data) throws -> Void {
        guard status == .connected || status == .stateless else {
            throw UniSocketError.error(detail: "socket is \(status)")
        }
        var bytesLeft = buffer.count
        var rc: Int
        while bytesLeft > 0 {
            let rangeLeft = Range(uncheckedBounds: (lower: buffer.index(buffer.startIndex, offsetBy: (buffer.count - bytesLeft)), upper: buffer.endIndex))
            let bufferLeft = buffer.subdata(in: rangeLeft)
            if let errstr = waitFor(.writable) {
                throw UniSocketError.error(detail: errstr)
            }
            if status == .stateless {
                rc = bufferLeft.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in return system_sendto(fd, ptr.baseAddress, bytesLeft, 0, peer_addrinfo.pointee.ai_addr, peer_addrinfo.pointee.ai_addrlen) }
            } else {
                rc = bufferLeft.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in return system_send(fd, ptr.baseAddress, bytesLeft, 0) }
            }
            if rc == -1 {
                let errstr = String(validatingCString: strerror(errno)) ?? "unknown error code"
                throw UniSocketError.error(detail: "failed to write to socket, \(errstr)")
            }
            bytesLeft = bytesLeft - rc
        }
    }

    public func recvfrom() throws -> Data {

        throw UniSocketError.error(detail: "not yet implemented")

    }

}
