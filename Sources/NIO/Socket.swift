//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(Linux)
import struct CNIOLinux.CNIOLinux_mmsghdr
#endif

public typealias IOVector = iovec

#if os(Linux)
internal typealias MMsgHdr = CNIOLinux_mmsghdr
#endif

// TODO: scattering support
final class Socket : BaseSocket {
    static var writevLimitBytes: Int {
        return Int(Int32.max)
    }
    static let writevLimitIOVectors: Int = Posix.UIO_MAXIOV

    init(protocolFamily: Int32) throws {
        let sock = try BaseSocket.newSocket(protocolFamily: protocolFamily)
        super.init(descriptor: sock)
    }
    
    override init(descriptor : Int32) {
        super.init(descriptor: descriptor)
    }
    
    func connect(to address: SocketAddress) throws -> Bool {
        switch address {
        case .v4(address: let addr, _):
            return try connectSocket(addr: addr)
        case .v6(address: let addr, _):
            return try connectSocket(addr: addr)
        case .unixDomainSocket(address: let addr):
            return try connectSocket(addr: addr)
        }
    }
    
    private func connectSocket<T>(addr: T) throws -> Bool {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't connect socket as it's not open anymore.")
        }
        var addr = addr
        return try withUnsafePointer(to: &addr) { ptr in
            try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                try Posix.connect(descriptor: self.descriptor, addr: ptr, size: MemoryLayout<T>.size)
            }
        }
    }
    
    func finishConnect() throws {
        let result: Int32 = try getOption(level: SOL_SOCKET, name: SO_ERROR)
        if result != 0 {
            throw IOError(errnoCode: result, function: "getsockopt")
        }
    }
    
    func write(pointer: UnsafePointer<UInt8>, size: Int) throws -> IOResult<Int> {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't write to socket as it's not open anymore.")
        }
        return try Posix.write(descriptor: self.descriptor, pointer: pointer, size: size)
    }

    func writev(iovecs: UnsafeBufferPointer<IOVector>) throws -> IOResult<Int> {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't writev to socket as it's not open anymore.")
        }

        return try Posix.writev(descriptor: self.descriptor, iovecs: iovecs)
    }
    
    func read(pointer: UnsafeMutablePointer<UInt8>, size: Int) throws -> IOResult<Int> {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't read from socket as it's not open anymore.")
        }

        return try Posix.read(descriptor: self.descriptor, pointer: pointer, size: size)
    }
    
    func sendFile(fd: Int32, offset: Int, count: Int) throws -> IOResult<Int> {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't write to socket as it's not open anymore.")
        }
      
        return try Posix.sendfile(descriptor: self.descriptor, fd: fd, offset: offset, count: count)
    }

    #if os(Linux)
    func recvmmsg(msgs: UnsafeMutableBufferPointer<MMsgHdr>) throws -> IOResult<Int> {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't read from socket as it's not open anymore.")
        }

        return try LinuxSocket.recvmmsg(sockfd: self.descriptor, msgvec: msgs.baseAddress!, vlen: CUnsignedInt(msgs.count), flags: 0, timeout: nil)
    }

    func sendmmsg(msgs: UnsafeMutableBufferPointer<MMsgHdr>) throws -> IOResult<Int> {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't write to socket as it's not open anymore.")
        }

        return try LinuxSocket.sendmmsg(sockfd: self.descriptor, msgvec: msgs.baseAddress!, vlen: CUnsignedInt(msgs.count), flags: 0)
    }
    #endif
    
    func shutdown(how: Shutdown) throws {
        guard self.open else {
            throw IOError(errnoCode: EBADF, reason: "can't shutdown socket as it's not open anymore.")
        }
        try Posix.shutdown(descriptor: self.descriptor, how: how)
    }
}
